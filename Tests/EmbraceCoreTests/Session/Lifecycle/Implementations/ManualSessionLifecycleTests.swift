//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

@MainActor
final class ManualSessionLifecycleTests: XCTestCase {

    var mockController = MockSessionController()
    var lifecycle: ManualSessionLifecycle!

    override func setUp() async throws {
        lifecycle = ManualSessionLifecycle(controller: mockController)
        lifecycle.setup()
    }

    override func tearDown() async throws {
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
        XCTAssertNotNil(mockController.currentSession)

        lifecycle.endSession()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertNil(mockController.currentSession)
    }
}
