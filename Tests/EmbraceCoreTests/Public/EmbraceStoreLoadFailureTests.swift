//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

/// Stores are in memory during tests unless built with `isTesting: false`. The tests using `makeFailingStorage()`
/// get a storage that really fails to load; the others drive `storeFailedToLoad` directly.
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
        }
        clients = []
        storage.coreData.destroy()
    }

    // MARK: - Real load failure

    func test_storageFailsToLoad_reportsItAndStopsTheSDK() throws {
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
        XCTAssertNil(client.currentSessionId())
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
        XCTAssertNil(client.currentSessionId())
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

    func test_storeFails_logIsNotHandedToTheUsersExporter() throws {
        // given a client with a log exporter configured by the user
        let exporter = InMemoryLogRecordExporter()
        let client = try makeClient(export: OpenTelemetryExport(logExporter: exporter))

        // when a store fails to load
        client.storeFailedToLoad("storage", error: loadError)
        drainProcessingQueue(of: client)

        // then the failure is reported, but not through the user's exporter
        XCTAssertEqual(try cachedStoreLoadFailureLogs(of: client).count, 1)
        XCTAssertFalse(
            exporter.finishedLogRecords.contains {
                $0.body?.description.contains("failed to load") == true
            })
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
        export: OpenTelemetryExport? = nil
    ) throws -> Embrace {
        let client = try Embrace(
            options: .init(
                appId: "debug",
                // unreachable, so nothing leaves the machine
                endpoints: .init(baseURL: "http://127.0.0.1:1", configBaseURL: "http://127.0.0.1:1"),
                captureServices: [],
                crashReporter: crashReporter,
                export: export
            ),
            embraceStorage: storage ?? self.storage
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
