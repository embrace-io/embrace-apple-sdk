//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class ManualSessionLifecycleTests: XCTestCase {

    var mockController = MockSessionController()
    var lifecycle: ManualSessionLifecycle!

    override func setUpWithError() throws {
        lifecycle = ManualSessionLifecycle(controller: mockController)
        lifecycle.setup()
    }

    override func tearDownWithError() throws {
        lifecycle = nil
    }

    // MARK: startSession

    func test_startSession_callsControllerStartSession() throws {
        lifecycle.startSession()

        XCTAssertTrue(mockController.didCallStartSession)
    }

    func test_startSession_ifControllerIsNil_doesNothing() throws {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = ManualSessionLifecycle(controller: controller!)
        lifecycle.setup()
        controller = nil

        lifecycle.startSession()

        XCTAssertNil(lifecycle.controller)
    }

    // MARK: endSession

    func test_endSession_ifControllerIsNil_doesNothing() throws {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = ManualSessionLifecycle(controller: controller!)
        lifecycle.setup()
        controller = nil

        lifecycle.endSession()

        XCTAssertNil(lifecycle.controller)
    }

    func test_endSession_withCurrentSession_callsControllerEndSession() throws {
        mockController.startSession(state: .foreground)
        XCTAssertNotNil(mockController.currentSessionId)

        lifecycle.endSession()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertNil(mockController.currentSessionId)
    }
}
