//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import XCTest

@testable import EmbraceCore

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
        client.storeFailedToLoad("storage")
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
        client.storeFailedToLoad("upload cache")

        // then the SDK is disabled right away
        XCTAssertFalse(client.isSDKEnabled)

        // and stopped once the main queue runs
        drainMainQueue()
        XCTAssertEqual(client.state, .stopped)
        XCTAssertNil(client.currentSessionId())
    }

    func test_storeFailsTwice_handledOnce() throws {
        // given a started client
        let client = try makeClient()
        try client.start()

        // when both stores fail to load
        client.storeFailedToLoad("storage")
        client.storeFailedToLoad("upload cache")
        drainMainQueue()

        // then the SDK is stopped
        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
    }

    private func makeClient() throws -> Embrace {
        try Embrace(
            options: .init(appId: "debug", captureServices: [], crashReporter: nil),
            embraceStorage: storage
        )
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }
}
