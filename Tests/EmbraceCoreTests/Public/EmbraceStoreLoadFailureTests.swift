//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceStorageInternal
import SQLite3
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

/// Stores are in memory during tests unless built with `isTesting: false`. The tests using `makeFailingStorage()`
/// or `makeFailingUpload()` get a store that really fails to load. The others use the loaded in-memory stores,
/// and call `storeFailedToLoad` directly when they need a failure.
final class EmbraceStoreLoadFailureTests: XCTestCase {

    var storage: EmbraceStorage!
    var clients: [Embrace] = []

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        // let any failure handling finish before the storage is destroyed
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

    func test_storageFailsToLoad_reportsItAndDisablesTheSDK() throws {
        // given a client whose storage fails to load
        let client = try makeClient(storage: try makeFailingStorage())
        waitForLoadFailureHandling(of: client)

        // then the SDK is disabled and won't start
        XCTAssertFalse(client.isSDKEnabled)
        try client.start()
        XCTAssertNotEqual(client.state, .started)

        // and the failure is reported with the real load error and the metadata the backend requires
        let log = try XCTUnwrap(cachedStoreLoadFailureLogs(of: client).first)
        XCTAssertEqual(log.attributes["emb.store_load.store"], "storage")
        XCTAssertEqual(log.attributes["emb.store_load.error_domain"], NSCocoaErrorDomain)
        XCTAssertNotNil(log.attributes["emb.store_load.error_code"])
        XCTAssertNotNil(log.attributes["emb.store_load.sqlite_error_code"])
        XCTAssertEqual(log.resource["app_version"] as? String, AppInfoCaptureService.criticalResources[AppResourceKey.appVersion.rawValue])
        XCTAssertEqual(log.resource["sdk_version"] as? String, EmbraceMeta.sdkVersion)
        XCTAssertNotNil(log.resource["sdk_platform"])
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
            $0.payloadTypes == LogType.crash.rawValue
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
            $0.payloadTypes == LogType.crash.rawValue
        }
        XCTAssertEqual(crashLogs.count, 1)
    }

    func test_storageFailsToLoad_legacyMetadataFileIsKept() throws {
        // given a storage that fails to load, with a legacy metadata file to migrate next to it
        let failingStorage = try makeFailingStorage()
        let legacyFile = try XCTUnwrap(failingStorage.options.storageMechanism.baseUrl)
            .appendingPathComponent("EmbraceMetadataTmp.sqlite")
        try Data().write(to: legacyFile)

        // when the metadata handler tries to migrate it
        _ = MetadataHandler(storage: failingStorage, sessionController: nil)

        // then the file is kept for a later launch, since nothing could be migrated
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyFile.path))
    }

    func test_uploadCacheFailsToLoad_disablesTheSDK() throws {
        // given a client whose upload cache fails to load
        let client = try makeClient(upload: try makeFailingUpload())
        XCTAssertEqual(client.upload?.isCacheLoaded, false)
        drainProcessingQueue(of: client)
        drainMainQueue()

        // then the SDK is disabled and won't start
        XCTAssertFalse(client.isSDKEnabled)
        try client.start()
        XCTAssertNotEqual(client.state, .started)
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
        // given an existing storage on disk
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: baseURL) }
        let storageOptions = EmbraceStorage.Options(
            storageMechanism: .onDisk(name: "EmbraceStorage", baseURL: baseURL, journalMode: .delete),
            enableBackgroundTasks: false
        )
        try EmbraceStorage(options: storageOptions, logger: MockLogger(), isTesting: false).coreData.save()

        // and another connection holding an exclusive lock on it, so loading it stalls
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(storageOptions.storageMechanism.fileURL!.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "BEGIN EXCLUSIVE", nil, nil, nil), SQLITE_OK)

        // (released after a few seconds anyway, so a regression that waits for the load fails instead of hanging)
        let releaseLock = lockReleaser(db)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { releaseLock() }

        // when setting up and starting the SDK
        let start = Date()
        let stalledStorage = try EmbraceStorage(options: storageOptions, logger: MockLogger(), isTesting: false)
        let client = try makeClient(storage: stalledStorage)
        try client.start()

        // then neither waits for the storage to load (the bound leaves CI headroom but stays below the 3s release)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        XCTAssertEqual(client.state, .started)

        // and the storage loads once the lock is released
        releaseLock()
        XCTAssertTrue(stalledStorage.coreData.isStoreLoaded)
        XCTAssertTrue(client.isSDKEnabled)
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
        client.storeFailedToLoad("storage", error: loadError)
        drainProcessingQueue(of: client)
        drainMainQueue()

        // when starting it
        try client.start()

        // then it doesn't start
        XCTAssertNotEqual(client.state, .started)
        XCTAssertFalse(client.isSDKEnabled)
        XCTAssertNil(client.sessionController.currentSession)
    }

    func test_storeFailsAfterStart_sdkStops() throws {
        // given a started client
        let client = try makeClient()
        try client.start()
        XCTAssertEqual(client.state, .started)

        // when one of its stores fails to load
        client.storeFailedToLoad("upload cache", error: loadError)

        // then the SDK is disabled right away
        XCTAssertFalse(client.isSDKEnabled)

        // and stopped once the failure is reported
        drainProcessingQueue(of: client)
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)
        XCTAssertNil(client.sessionController.currentSession)
    }

    func test_storeFailsOffTheMainThread_sdkStops() throws {
        // given a started client
        let client = try makeClient()
        try client.start()

        // when a store fails to load, reported from a background queue as the stores do
        DispatchQueue.global().sync {
            client.storeFailedToLoad("storage", error: loadError)
        }

        // then the SDK is disabled and stopped
        XCTAssertFalse(client.isSDKEnabled)
        drainProcessingQueue(of: client)
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)
    }

    func test_storeFailsTwice_handledOnce() throws {
        // given a started client
        let client = try makeClient()
        try client.start()

        // when both stores fail to load
        client.storeFailedToLoad("storage", error: loadError)
        client.storeFailedToLoad("upload cache", error: loadError)
        drainProcessingQueue(of: client)
        drainMainQueue()

        // then the SDK is stopped
        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)

        // and only the first failure is reported
        let logs = try cachedStoreLoadFailureLogs(of: client)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.attributes["emb.store_load.store"], "storage")
    }

    func test_storeFails_sendsErrorLogWithErrorAndMetadata() throws {
        // given a client
        let client = try makeClient()

        // when its storage fails to load
        client.storeFailedToLoad("storage", error: loadError)
        drainProcessingQueue(of: client)

        // then an error log reporting the failure is cached for upload
        let logs = try cachedStoreLoadFailureLogs(of: client)
        XCTAssertEqual(logs.count, 1)
        let log = try XCTUnwrap(logs.first)
        XCTAssertEqual(log.body, "Embrace SDK stopped because its storage failed to load")
        XCTAssertEqual(log.severity, "ERROR")

        // as a regular log the app's owner can see
        XCTAssertNil(log.attributes["emb.private"])
        XCTAssertEqual(log.attributes["emb.type"], "sys.log")

        XCTAssertEqual(log.attributes["emb.store_load.store"], "storage")
        XCTAssertEqual(log.attributes["emb.store_load.error_domain"], NSCocoaErrorDomain)
        XCTAssertEqual(log.attributes["emb.store_load.error_code"], "256")
        XCTAssertEqual(log.attributes["emb.store_load.sqlite_error_code"], "14")

        // and it carries the metadata the backend requires
        XCTAssertNotNil(log.resource["app_version"])
        XCTAssertNotNil(log.resource["sdk_version"])
        XCTAssertNotNil(log.resource["sdk_platform"])
    }

    func test_storeLoadErrorAttributes() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 2)
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 256,
            userInfo: [NSSQLiteErrorDomain: 14, NSUnderlyingErrorKey: underlying]
        )

        let attributes = Embrace.storeLoadErrorAttributes(store: "upload cache", error: error)

        XCTAssertEqual(attributes["emb.store_load.store"], "upload cache")
        XCTAssertEqual(attributes["emb.store_load.error_domain"], NSCocoaErrorDomain)
        XCTAssertEqual(attributes["emb.store_load.error_code"], "256")
        XCTAssertEqual(attributes["emb.store_load.sqlite_error_code"], "14")
        XCTAssertEqual(attributes["emb.store_load.underlying_error"], "\(NSPOSIXErrorDomain) 2")
        XCTAssertNotNil(attributes["emb.store_load.error_message"])
    }

    // MARK: - Helpers

    /// The error Core Data reports when the store's path can't be opened.
    private let loadError = NSError(domain: NSCocoaErrorDomain, code: 256, userInfo: [NSSQLiteErrorDomain: 14])

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

    /// Releases the exclusive lock held by `db` once, from whichever caller gets there first.
    private func lockReleaser(_ db: OpaquePointer?) -> () -> Void {
        let lock = NSLock()
        var released = false
        return {
            lock.lock()
            defer { lock.unlock() }
            guard !released else { return }
            released = true
            XCTAssertEqual(sqlite3_exec(db, "COMMIT", nil, nil, nil), SQLITE_OK)
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
    /// queue (where `isStoreLoaded` waits), then the failure is reported on the processing queue.
    private func waitForLoadFailureHandling(of client: Embrace) {
        XCTAssertFalse(client.storage.coreData.isStoreLoaded)
        drainProcessingQueue(of: client)
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

    private func drainProcessingQueue(of client: Embrace) {
        client.processingQueue.sync {}
        // the upload is cached on the upload queue
        client.upload?.queue.sync {}
    }

    private struct CachedLog {
        let body: String?
        let severity: String?
        let attributes: [String: String]
        let resource: [String: Any]
    }

    private func cachedStoreLoadFailureLogs(of client: Embrace) throws -> [CachedLog] {
        let records = try XCTUnwrap(client.upload?.cache.fetchAllUploadData())
        return try records.filter { $0.type == EmbraceUploadType.log.rawValue }.compactMap { record in
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: try record.data.gunzipped()) as? [String: Any])
            let logs = (payload["data"] as? [String: Any])?["logs"] as? [[String: Any]] ?? []
            return logs.first { ($0["body"] as? String)?.contains("failed to load") == true }.map { log in
                CachedLog(
                    body: log["body"] as? String,
                    severity: log["severity_text"] as? String,
                    attributes: Dictionary(
                        (log["attributes"] as? [[String: String]] ?? []).compactMap { attribute in
                            attribute["key"].map { ($0, attribute["value"] ?? "") }
                        },
                        uniquingKeysWith: { first, _ in first }
                    ),
                    resource: payload["resource"] as? [String: Any] ?? [:]
                )
            }
        }
    }
}
