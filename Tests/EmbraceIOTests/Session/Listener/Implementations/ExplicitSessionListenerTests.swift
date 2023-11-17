//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceIO

final class ExplicitSessionListenerTests: XCTestCase {

    var mockController = MockSessionController()
    var listener: ExplicitSessionListener!

    override func setUpWithError() throws {
        listener = ExplicitSessionListener(controller: mockController)
    }

    override func tearDownWithError() throws {
        listener = nil
    }

    // MARK: startSession

    func test_startSession_callsControllerStartSession() throws {
        listener.startSession()

        XCTAssertTrue(mockController.didCallStartSession)
    }

    func test_startSession_ifControllerIsNil_doesNothing() throws {
        var controller: MockSessionController? = MockSessionController()
        listener = ExplicitSessionListener(controller: controller!)
        controller = nil

        listener.startSession()

        XCTAssertNil(listener.controller)
    }

    // MARK: endSession

    func test_endSession_ifControllerIsNil_doesNothing() throws {
        var controller: MockSessionController? = MockSessionController()
        listener = ExplicitSessionListener(controller: controller!)
        controller = nil

        listener.endSession()

        XCTAssertNil(listener.controller)
    }

    func test_endSession_withCurrentSession_callsControllerEndSession() throws {
        let session = mockController.createSession(state: .foreground)
        mockController.start(session: session)
        XCTAssertNotNil(mockController.currentSession)

        listener.endSession()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertNil(mockController.currentSession)
    }

}
