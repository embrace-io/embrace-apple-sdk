//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorageInternal

final class MetadataHandler_UserTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        sessionController = nil
    }

    func test_setProperties_initially() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        handler.userName = "example"
        handler.userIdentifier = "my-example-identifier"
        handler.userEmail = "example@example.com"

        XCTAssertEqual(handler.userName, "example")
        XCTAssertEqual(handler.userIdentifier, "my-example-identifier")
        XCTAssertEqual(handler.userEmail, "example@example.com")
    }

    func test_setProperties_canByUpdated() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        handler.userName = "example"
        handler.userIdentifier = "my-example-identifier"
        handler.userEmail = "example@example.com"

        handler.userName = "updated_example"
        handler.userIdentifier = "my-updated-identifier"
        handler.userEmail = "updated@example.com"

        XCTAssertEqual(handler.userName, "updated_example")
        XCTAssertEqual(handler.userIdentifier, "my-updated-identifier")
        XCTAssertEqual(handler.userEmail, "updated@example.com")
    }

    func test_setProperties_canBeCleared_Individually() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        handler.userName = "example"
        handler.userIdentifier = "my-example-identifier"
        handler.userEmail = "example@example.com"

        handler.userName = nil
        XCTAssertNil(handler.userName)

        handler.userIdentifier = nil
        XCTAssertNil(handler.userIdentifier)

        handler.userEmail = nil
        XCTAssertNil(handler.userEmail)
    }

    func test_setProperties_canBeCleared_AllTogether() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        handler.userName = "example"
        handler.userIdentifier = "my-example-identifier"
        handler.userEmail = "example@example.com"

        handler.clearUserProperties()

        XCTAssertNil(handler.userName)
        XCTAssertNil(handler.userIdentifier)
        XCTAssertNil(handler.userEmail)
    }

}
