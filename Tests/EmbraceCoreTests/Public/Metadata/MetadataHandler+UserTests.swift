//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class MetadataHandler_UserTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.storage = storage
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        sessionController = nil
    }

    func test_setProperties_initially() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        handler.userIdentifier = "my-example-identifier"

        XCTAssertEqual(handler.userIdentifier, "my-example-identifier")
    }

    func test_setProperties_canByUpdated() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        handler.userIdentifier = "my-example-identifier"

        handler.userIdentifier = "my-updated-identifier"

        XCTAssertEqual(handler.userIdentifier, "my-updated-identifier")
    }

    func test_setProperties_canBeCleared_Individually() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        handler.userIdentifier = "my-example-identifier"
        handler.userIdentifier = nil
        XCTAssertNil(handler.userIdentifier)
    }
}
