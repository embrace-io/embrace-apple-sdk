//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceStorageInternal
import XCTest

@testable import EmbraceCore
@testable import EmbraceUploadInternal

/// Stores are always in memory during tests, so they can't fail to load:
/// these tests drive `storeFailedToLoad` directly. See `CoreDataWrapperTests` for the load itself.
final class EmbraceStoreLoadFailureTests: XCTestCase {

    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

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
    }

    func test_storeFails_sendsErrorLogWithErrorAndMetadata() throws {
        // given a client
        let client = try makeClient()

        // when its storage fails to load
        client.storeFailedToLoad("storage", error: loadError)
        drainProcessingQueue(of: client)

        // then an error log reporting the failure is cached for upload
        let records = try XCTUnwrap(client.upload?.cache.fetchAllUploadData())
        let logs = records.filter { $0.type == EmbraceUploadType.log.rawValue }
        XCTAssertEqual(logs.count, 1)

        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(logs.first).data.gunzipped()) as? [String: Any])
        let log = try XCTUnwrap(((payload["data"] as? [String: Any])?["logs"] as? [[String: Any]])?.first)
        XCTAssertEqual(log["body"] as? String, "Embrace SDK stopped because its storage failed to load")

        let attributes = Dictionary(
            uniqueKeysWithValues: (log["attributes"] as? [[String: String]] ?? []).compactMap { attribute in
                attribute["key"].map { ($0, attribute["value"] ?? "") }
            })
        // as a regular log the app's owner can see
        XCTAssertNil(attributes["emb.private"])
        XCTAssertEqual(attributes["emb.type"], "sys.log")
        XCTAssertEqual(log["severity_text"] as? String, "ERROR")
        XCTAssertEqual(attributes["emb.store_load.store"], "storage")
        XCTAssertEqual(attributes["emb.store_load.error_domain"], NSCocoaErrorDomain)
        XCTAssertEqual(attributes["emb.store_load.error_code"], "256")
        XCTAssertEqual(attributes["emb.store_load.sqlite_error_code"], "14")

        // and it carries the metadata the backend requires
        let resource = try XCTUnwrap(payload["resource"] as? [String: Any])
        XCTAssertNotNil(resource["app_version"])
        XCTAssertNotNil(resource["sdk_version"])
        XCTAssertNotNil(resource["sdk_platform"])
    }

    func test_storeLoadErrorAttributes() {
        let attributes = Embrace.storeLoadErrorAttributes(store: "upload cache", error: loadError)

        XCTAssertEqual(attributes["emb.store_load.store"], "upload cache")
        XCTAssertEqual(attributes["emb.store_load.error_domain"], NSCocoaErrorDomain)
        XCTAssertEqual(attributes["emb.store_load.error_code"], "256")
        XCTAssertEqual(attributes["emb.store_load.sqlite_error_code"], "14")
        XCTAssertNotNil(attributes["emb.store_load.error_message"])
    }

    /// The error Core Data reports when the store's path can't be opened.
    private let loadError = NSError(domain: NSCocoaErrorDomain, code: 256, userInfo: [NSSQLiteErrorDomain: 14])

    private func makeClient() throws -> Embrace {
        try Embrace(
            options: .init(
                appId: "debug",
                // unreachable, so nothing leaves the machine
                endpoints: .init(baseURL: "http://127.0.0.1:1", configBaseURL: "http://127.0.0.1:1"),
                captureServices: [],
                crashReporter: nil
            ),
            embraceStorage: storage
        )
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    private func drainProcessingQueue(of client: Embrace) {
        let drained = expectation(description: "processing queue drained")
        client.processingQueue.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
        // the upload is cached on the upload queue
        client.upload?.queue.sync {}
    }
}
