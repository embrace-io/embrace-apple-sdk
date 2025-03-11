//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal

#if os(iOS)

// swiftlint:disable type_name
final class iOSSessionLifecycleTests: XCTestCase {
// swiftlint:enable type_name

    var mockController = MockSessionController()
    var lifecycle: iOSSessionLifecycle!

    override func setUpWithError() throws {
        lifecycle = iOSSessionLifecycle(controller: mockController)
        lifecycle.setup()
    }

    override func tearDownWithError() throws {
        lifecycle = nil
    }

    // MARK: startSession

    func test_startSession_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = iOSSessionLifecycle(controller: controller!)
        controller = nil

        lifecycle.startSession()

        XCTAssertNil(lifecycle.controller)
    }

    func test_startSession_callsControllerStartSession_andSetsSessionState() {
        lifecycle.startSession()

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.foreground)
    }

    func test_startSession_whenControllerHasCurrentSession_callsEndSession_andThenStartSession() {
        mockController.startSession(state: .foreground)

        lifecycle.startSession()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.foreground)
    }

    func test_startSession_fromBackgroundQueue_callsControllerStartSession_andSetsSessionState() {
        let expectation = self.expectation(description: "startSession")
        DispatchQueue.global().async {
            self.lifecycle.startSession()
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.1, handler: nil)

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.foreground)
    }

    // MARK: endSession

    func test_endSession_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = iOSSessionLifecycle(controller: controller!)
        controller = nil

        lifecycle.endSession()

        XCTAssertNil(lifecycle.controller)
    }

    func test_endSession_whenControllerHasNoCurrentSession_doesNotCallEndSession() {
        XCTAssertNil(mockController.currentSessionId)

        lifecycle.endSession()

        XCTAssertFalse(mockController.didCallEndSession)
    }

    func test_endSession_whenControllerHasCurrentSession_callsEndSession() {
        mockController.startSession(state: .foreground)

        lifecycle.endSession()

        XCTAssertTrue(mockController.didCallEndSession)
    }

    // MARK: appDidBecomeActive

    func test_appDidBecomeActive_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = iOSSessionLifecycle(controller: controller!)
        controller = nil

        lifecycle.appDidBecomeActive()

        XCTAssertNil(lifecycle.controller)
    }

    func test_appDidBecomeActive_hasNoCurrentSession_startsForegroundSession() {
        XCTAssertNil(mockController.currentSessionId)

        lifecycle.appDidBecomeActive()

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertNotNil(mockController.currentSessionId)
        XCTAssertEqual(mockController.currentSessionState, SessionState.foreground)
    }

    func test_appDidBecomeActive_hasCurrentSession_withStateForeground_doesNothing() {
        mockController.startSession(state: .foreground)

        mockController.didCallStartSession = false

        lifecycle.appDidBecomeActive()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.foreground)
    }

    func test_appDidBecomeActive_hasCurrentSession_coldStartTrue_callsUpdateToForegroundState_keepsSameSession() {
        mockController.startSession(state: .background)
        mockController.currentSessionColdStart = true

        mockController.didCallStartSession = false

        mockController.onUpdateSession { sessionId, state, appTerminated in
            XCTAssertEqual(sessionId, self.mockController.currentSessionId)
            XCTAssertEqual(state, .foreground)
            XCTAssertNil(appTerminated)
        }

        lifecycle.appDidBecomeActive()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallUpdateSession)
    }

    func test_appDidBecomeActive_hasCurrentSession_withColdStartFalse_createsNewForegroundSession() {
        mockController.startSession(state: .background)
        mockController.currentSessionColdStart = false

        lifecycle.appDidBecomeActive()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.foreground)
    }

    // MARK: appDidEnterBackground

    func test_appDidEnterBackground_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = iOSSessionLifecycle(controller: controller!)
        controller = nil

        lifecycle.appDidEnterBackground()

        XCTAssertNil(lifecycle.controller)
    }

    func test_appDidEnterBackground_hasNoCurrentSession_startsBackgroundSession() {
        XCTAssertNil(mockController.currentSessionId)

        lifecycle.appDidEnterBackground()

        XCTAssertNotNil(mockController.currentSessionId)
        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.background)
    }

    func test_appDidEnterBackground_hasCurrentSession_withStateBackground_doesNothing() {
        mockController.startSession(state: .background)
        mockController.didCallStartSession = false

        lifecycle.appDidEnterBackground()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.background)
    }

    func test_appDidEnterBackground_hasCurrentSession_withStateForeground_createsNewBackgroundSession() {
        mockController.startSession(state: .foreground)

        lifecycle.appDidEnterBackground()

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertEqual(mockController.currentSessionState, SessionState.background)
    }

    // MARK: appWillTerminate

    func test_appWillTerminate_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        lifecycle = iOSSessionLifecycle(controller: controller!)
        controller = nil

        lifecycle.appWillTerminate()

        XCTAssertNil(lifecycle.controller)
    }

    func test_appWillTerminate_hasNoCurrentSession_doesNothing() {
        XCTAssertNil(mockController.currentSessionId)

        lifecycle.appWillTerminate()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
    }

    func test_appWillTerminate_hasCurrentForegroundSession_marksItAsAppTerminated() {
        mockController.startSession(state: .foreground)

        mockController.onUpdateSession { sessionId, state, appTerminated in
            XCTAssertEqual(sessionId, self.mockController.currentSessionId)
            XCTAssertEqual(appTerminated, true)
            XCTAssertNil(state)
        }

        mockController.didCallStartSession = false

        lifecycle.appWillTerminate()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallUpdateSession)
    }

    func test_appWillTerminate_hasCurrentBackgroundSession_marksItAsAppTerminated() {
        mockController.startSession(state: .background)

        mockController.onUpdateSession { sessionId, state, appTerminated in
            XCTAssertEqual(sessionId, self.mockController.currentSessionId)
            XCTAssertEqual(appTerminated, true)
            XCTAssertNil(state)
        }

        mockController.didCallStartSession = false

        lifecycle.appWillTerminate()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallUpdateSession)
    }

    // MARK: currentState
    func test_currentState_defaultValue() {
        let lifecycle = iOSSessionLifecycle(controller: mockController)

        XCTAssertEqual(lifecycle.currentState, .background)
    }

    func test_currentState_initialFetch() {
        let lifecycle = iOSSessionLifecycle(controller: mockController)
        lifecycle.setup()

        XCTAssertEqual(lifecycle.currentState, .foreground)
    }

    func test_currentState_appDidBecomeActive() {
        lifecycle.appDidBecomeActive()

        XCTAssertEqual(lifecycle.currentState, .foreground)
    }

    func test_currentState_appDidEnterBackground() {
        lifecycle.appDidEnterBackground()

        XCTAssertEqual(lifecycle.currentState, .background)
    }
}

#endif
