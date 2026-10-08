//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import SQLite3
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

/// Stores are in memory during tests unless built with `isTesting: false`. The tests using `makeFailingStorage()`
/// or `makeFailingUpload()` get a store that really fails to load, and the ones using `makeStalledStorage()` one whose
/// load is stalled. The others use the loaded in-memory stores, and call `storeFailedToLoad` directly when they need
/// a failure.
final class EmbraceStoreLoadFailureTests: XCTestCase {

    var storage: EmbraceStorage!
    var clients: [Embrace] = []

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        // drain the work `start()` queued on the processing queue before the storage is destroyed
        // (it only hands the unsent data over: the sending itself may still be running on other queues)
        for client in clients {
            drainProcessingQueue(of: client)
            if client.state == .started {
                try client.stop()
            }
        }
        clients = []
        storage.coreData.destroy()
    }

    // MARK: - Real load failure

    func test_storageFailsToLoad_disablesTheSDK() throws {
        // given a client whose storage fails to load
        let client = try makeClient(storage: try makeFailingStorage())
        waitForLoadFailureHandling(of: client)

        // then the SDK is disabled and won't start
        XCTAssertFalse(client.isSDKEnabled)
        try client.start()
        XCTAssertEqual(client.state, .stopped)
    }

    func test_sendUnsentData_whenStorageFailedToLoad_keepsCrashReports() throws {
        // given a client whose storage failed to load, with a crash report from an earlier launch
        let crashReporter = CrashReporterMock()
        let client = try makeClient(storage: try makeFailingStorage(), crashReporter: crashReporter)
        waitForLoadFailureHandling(of: client)

        // when sending the unsent data (as `start()` does if it runs before the load fails)
        sendUnsentData(of: client)

        // then the crash report is neither sent nor deleted
        XCTAssertEqual(crashReporter.mockReports.count, 1)
        let crashLogs = try XCTUnwrap(client.upload?.cache.fetchAllUploadData()).filter {
            $0.payloadTypes == EmbraceType.crash.rawValue
        }
        XCTAssertTrue(crashLogs.isEmpty)
    }

    func test_sendUnsentData_whenStorageLoaded_sendsCrashReports() throws {
        // given a client whose storage loaded, with a crash report from an earlier launch
        let crashReporter = CrashReporterMock()
        let client = try makeClient(crashReporter: crashReporter)

        // when sending the unsent data
        sendUnsentData(of: client)

        // then the crash report is sent (cached for upload) and deleted
        XCTAssertTrue(crashReporter.mockReports.isEmpty)
        let crashLogs = try XCTUnwrap(client.upload?.cache.fetchAllUploadData()).filter {
            $0.payloadTypes == EmbraceType.crash.rawValue
        }
        XCTAssertEqual(crashLogs.count, 1)
    }

    func test_uploadCacheFailsToLoad_disablesTheSDK() throws {
        // given a client whose upload cache fails to load
        let client = try makeClient(upload: try makeFailingUpload())
        XCTAssertEqual(client.upload?.isCacheLoaded, false)
        drainMainQueue()

        // then the SDK is disabled and won't start
        XCTAssertFalse(client.isSDKEnabled)
        try client.start()
        XCTAssertEqual(client.state, .stopped)
    }

    func test_sendUnsentData_whenUploadCacheFailedToLoad_keepsTheData() throws {
        // given a client whose upload cache failed to load,
        // with metadata from an earlier process that has no session (so it would be cleaned up)
        let earlierProcessId = EmbraceIdentifier.random.stringValue
        storage.addMetadata(key: "test", value: "value", type: .resource, lifespan: .process, lifespanId: earlierProcessId)
        let client = try makeClient(upload: try makeFailingUpload())

        // when sending the unsent data
        sendUnsentData(of: client)

        // then nothing is cleaned up, so the data from earlier launches can still be sent later
        XCTAssertNotNil(
            storage.fetchMetadata(key: "test", type: .resource, lifespan: .process, lifespanId: earlierProcessId))
    }

    func test_start_sendsUnsentData() throws {
        // given a client with a crash report from an earlier launch
        let crashReporter = CrashReporterMock()
        let client = try makeClient(crashReporter: crashReporter)

        // when starting it
        try client.start()

        // then the crash report is sent (cached for upload) and deleted
        wait(timeout: .longTimeout, interval: .shortInterval) { crashReporter.mockReports.isEmpty }
        XCTAssertTrue(crashReporter.mockReports.isEmpty)
    }

    func test_setupAndStart_doNotWaitForAStalledStorage() throws {
        // given an existing storage on disk whose load stalls
        let (stalledStorage, releaseLock) = try makeStalledStorage()

        // when setting up and starting the SDK
        let client = try makeClient(storage: stalledStorage)
        try client.start()

        // then neither waited for the storage to load: the lock is still held
        XCTAssertTrue(releaseLock(), "setup or start waited for the storage to load")
        XCTAssertEqual(client.state, .started)

        // and the storage loads once the lock is released
        XCTAssertTrue(stalledStorage.coreData.isStoreLoaded)
        XCTAssertTrue(client.isSDKEnabled)
    }

    func test_start_withAStalledStorage_startsThePartAndResolvesItsUserSessionOnceLoaded() throws {
        // given an existing storage on disk whose load stalls
        let (stalledStorage, releaseLock) = try makeStalledStorage()

        // when starting the SDK
        let client = try makeClient(storage: stalledStorage)
        try client.start()

        // then the first part started right away, without a user session yet
        let part = try XCTUnwrap(client.sessionController.currentSession)
        XCTAssertNil(part.userSessionId)
        XCTAssertNil(client.currentUserSessionId())

        // and once the storage loads, the part gets its user session, in memory and in its record
        XCTAssertTrue(releaseLock(), "start waited for the storage to load")
        XCTAssertTrue(stalledStorage.coreData.isStoreLoaded)
        let userSessionId = try XCTUnwrap(client.currentUserSessionId())
        XCTAssertEqual(client.sessionController.currentSession?.id, part.id)
        XCTAssertEqual(client.sessionController.currentSession?.userSessionId?.stringValue, userSessionId)
        XCTAssertEqual(stalledStorage.fetchSession(id: part.id)?.userSessionId?.stringValue, userSessionId)
    }

    func test_start_withAStalledStorage_userSessionMetadataSetRightAway_isKept() throws {
        // given a started SDK whose storage load stalls
        let (stalledStorage, releaseLock) = try makeStalledStorage()
        let client = try makeClient(storage: stalledStorage)
        try client.start()

        // when setting a user-session property and persona before the user session is resolved
        client.metadata.addProperty(key: "plan", value: "pro", lifespan: .userSession)
        client.metadata.add(persona: "tester", lifespan: .userSession)

        // then once the storage loads, they're stored for the user session the part was resolved to
        XCTAssertTrue(releaseLock(), "start waited for the storage to load")
        client.metadata.synchronizationQueue.sync {}
        let userSessionId = EmbraceIdentifier(stringValue: try XCTUnwrap(client.currentUserSessionId()))
        let properties = stalledStorage.fetchCustomProperties(userSessionId: userSessionId, processId: ProcessIdentifier.current)
        XCTAssertEqual(properties.first { $0.key == "plan" }?.value, "pro")
        let personas = stalledStorage.fetchPersonaTags(userSessionId: userSessionId, processId: ProcessIdentifier.current)
        XCTAssertTrue(personas.contains { $0.key == "tester" })
    }

    func test_start_withAStalledStorage_logCreatedRightAway_getsTheUserSession() throws {
        // given a started SDK whose storage load stalls
        let (stalledStorage, releaseLock) = try makeStalledStorage()
        let client = try makeClient(storage: stalledStorage)
        try client.start()

        // when creating a log before the user session is resolved
        var createdLog: EmbraceLog?
        let created = expectation(description: "log created")
        client.logController.createLog("early", severity: .info) { log in
            createdLog = log
            created.fulfill()
        }

        // then once the storage loads, the log has the user session the part was resolved to
        XCTAssertTrue(releaseLock(), "start waited for the storage to load")
        wait(for: [created], timeout: .defaultTimeout)
        let attributes = try XCTUnwrap(createdLog).attributes
        XCTAssertEqual(attributes[LogSemantics.keyUserSessionId] as? String, try XCTUnwrap(client.currentUserSessionId()))
    }

    func test_start_givesMetricKitThePriorProcessLastPart() throws {
        // given the last part of an earlier process
        let priorPartId = EmbraceIdentifier.random
        storage.addSession(
            id: priorPartId,
            processId: .random,
            state: .foreground,
            traceId: "trace",
            spanId: "span",
            startTime: Date().addingTimeInterval(-60),
            endTime: Date().addingTimeInterval(-30)
        )

        // when starting the SDK
        let client = try makeClient()
        try client.start()

        // then MetricKit gets that part, not this process's first one
        wait(timeout: .longTimeout, interval: .shortInterval) { client.metricKit.lastSession != nil }
        XCTAssertEqual(client.metricKit.lastSession?.id, priorPartId)
    }

    func test_start_continuesThePriorProcessUserSession() throws {
        // given the last part of an earlier process, in a user session that hasn't expired
        let priorUserSessionId = EmbraceIdentifier.random
        storage.addSession(
            id: .random,
            processId: .random,
            state: .foreground,
            traceId: "trace",
            spanId: "span",
            startTime: Date().addingTimeInterval(-60),
            endTime: Date().addingTimeInterval(-30),
            lastHeartbeatTime: Date().addingTimeInterval(-30),
            userSessionId: priorUserSessionId,
            userSessionStartTime: Date().addingTimeInterval(-60),
            userSessionMaxDuration: 3600,
            userSessionInactivityTimeout: 1800,
            userSessionLastForegroundEnd: Date().addingTimeInterval(-30),
            userSessionPartIndex: 1
        )

        // when starting the SDK
        let client = try makeClient()
        try client.start()

        // then the first part joins that user session once it's resolved on the storage queue
        XCTAssertTrue(storage.coreData.isStoreLoaded)
        XCTAssertEqual(client.currentUserSessionId(), priorUserSessionId.stringValue)
        let part = try XCTUnwrap(client.sessionController.currentSession)
        XCTAssertEqual(part.userSessionId, priorUserSessionId)
        XCTAssertEqual(part.userSessionPartIndex, 2)
    }

    // MARK: - storeFailedToLoad

    func test_storesLoaded_sdkStarts() throws {
        // given a client whose stores loaded
        let client = try makeClient()
        XCTAssertTrue(storage.coreData.isStoreLoaded)
        drainMainQueue()

        // when starting it
        try client.start()

        // then it starts
        XCTAssertEqual(client.state, .started)
        XCTAssertTrue(client.isSDKEnabled)
    }

    func test_storeFailsBeforeStart_sdkDoesNotStart() throws {
        // given a client whose store failed to load before it was started
        let client = try makeClient()
        client.storeFailedToLoad("storage")
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)

        // when starting it
        try client.start()

        // then it doesn't start
        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
        XCTAssertNil(client.sessionController.currentSession)
    }

    func test_storeFailsAfterStart_sdkStops() throws {
        // given a started client
        let client = try makeClient()
        try client.start()
        XCTAssertEqual(client.state, .started)

        // when one of its stores fails to load
        client.storeFailedToLoad("upload cache")

        // then it's stopped on the main thread
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
        XCTAssertNil(client.sessionController.currentSession)
    }

    func test_storeFailsRightBeforeStart_sdkStartsThenStops() throws {
        // given a client whose store failure is reported, but not yet handled on the main thread
        let client = try makeClient()
        client.storeFailedToLoad("storage")

        // when starting it before that
        try client.start()

        // then it starts, and is stopped once the failure is handled, as if the store failed after `start()`
        XCTAssertEqual(client.state, .started)
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
        XCTAssertNil(client.sessionController.currentSession)
    }

    func test_storeFailsOffTheMainThread_sdkStops() throws {
        // given a started client
        let client = try makeClient()
        try client.start()

        // when a store fails to load, reported from a background queue as the stores do
        DispatchQueue.global().sync {
            client.storeFailedToLoad("storage")
        }

        // then the SDK is stopped on the main thread
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
    }

    // MARK: - Helpers

    private func makeClient(
        storage: EmbraceStorage? = nil,
        crashReporter: CrashReporter? = nil,
        upload: EmbraceUpload? = nil
    ) throws -> Embrace {
        let client = try Embrace(
            options: .init(
                appId: "debug",
                // unreachable, so nothing leaves the machine
                endpoints: .init(baseURL: "http://127.0.0.1:1", configBaseURL: "http://127.0.0.1:1"),
                captureServices: [],
                crashReporter: crashReporter
            ),
            embraceStorage: storage ?? self.storage,
            embraceUpload: upload
        )
        clients.append(client)
        return client
    }

    /// An on-disk storage whose store really fails to load: there's a directory where its file should be.
    private func makeFailingStorage() throws -> EmbraceStorage {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: baseURL) }

        let storageMechanism: StorageMechanism = .onDisk(name: "EmbraceStorage", baseURL: baseURL, journalMode: .delete)
        try FileManager.default.createDirectory(at: storageMechanism.fileURL!, withIntermediateDirectories: true)

        return try EmbraceStorage(
            options: .init(storageMechanism: storageMechanism, enableBackgroundTasks: false),
            logger: MockLogger(),
            isTesting: false
        )
    }

    /// An existing on-disk storage whose load stalls: another connection holds an exclusive lock on it until the
    /// returned closure releases it (see `lockReleaser`). It's released anyway after a while, so a regression that
    /// waits for the load fails instead of hanging.
    private func makeStalledStorage() throws -> (EmbraceStorage, () -> Bool) {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: baseURL) }
        let storageOptions = EmbraceStorage.Options(
            storageMechanism: .onDisk(name: "EmbraceStorage", baseURL: baseURL, journalMode: .delete),
            enableBackgroundTasks: false
        )
        try EmbraceStorage(options: storageOptions, logger: MockLogger(), isTesting: false).coreData.save()

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(storageOptions.storageMechanism.fileURL!.path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "BEGIN EXCLUSIVE", nil, nil, nil), SQLITE_OK)

        let releaseLock = lockReleaser(db)
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { _ = releaseLock() }
        addTeardownBlock {
            _ = releaseLock()
            sqlite3_close(db)
        }

        let stalledStorage = try EmbraceStorage(options: storageOptions, logger: MockLogger(), isTesting: false)
        return (stalledStorage, releaseLock)
    }

    /// Releases the exclusive lock held by `db` once, from whichever caller gets there first.
    /// The returned closure returns whether that call released it.
    private func lockReleaser(_ db: OpaquePointer?) -> () -> Bool {
        let lock = NSLock()
        var released = false
        return {
            lock.lock()
            defer { lock.unlock() }
            guard !released else { return false }
            released = true
            XCTAssertEqual(sqlite3_exec(db, "COMMIT", nil, nil, nil), SQLITE_OK)
            return true
        }
    }

    /// An upload module whose cache store really fails to load: there's a directory where its file should be.
    private func makeFailingUpload() throws -> EmbraceUpload {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: baseURL) }

        let storageMechanism: StorageMechanism = .onDisk(name: "EmbraceUploadStorage", baseURL: baseURL, journalMode: .delete)
        try FileManager.default.createDirectory(at: storageMechanism.fileURL!, withIntermediateDirectories: true)

        // unreachable, so nothing leaves the machine
        let url = URL(string: "http://127.0.0.1:1")!
        return try EmbraceUpload(
            options: .init(
                endpoints: .init(spansURL: url, logsURL: url, attachmentsURL: url),
                cache: .init(storageMechanism: storageMechanism, enableBackgroundTasks: false),
                metadata: .init(apiKey: "debug", userAgent: "test", deviceId: "test")
            ),
            logger: MockLogger(),
            queue: DispatchQueue(label: "EmbraceStoreLoadFailureTests.upload"),
            isTesting: false
        )
    }

    /// Waits until the client has handled its storage's load failure: the load result is reported on the storage
    /// queue (where `isStoreLoaded` waits), then the SDK is stopped on the main thread.
    private func waitForLoadFailureHandling(of client: Embrace) {
        XCTAssertFalse(client.storage.coreData.isStoreLoaded)
        drainMainQueue()
    }

    private func sendUnsentData(of client: Embrace) {
        let sent = expectation(description: "unsent data sent")
        client.sendUnsentData { sent.fulfill() }
        wait(for: [sent], timeout: 5)
        // the uploads are cached on the upload queue
        client.upload?.queue.sync {}
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    /// Drains the processing queue, then whatever it has handed to the upload queue so far.
    private func drainProcessingQueue(of client: Embrace) {
        client.processingQueue.sync {}
        client.upload?.queue.sync {}
    }
}
