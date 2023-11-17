//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
import EmbraceCommon

#if os(iOS)

final class iOSAppListenerTests: XCTestCase {

    var mockController = MockSessionController()
    var listener: iOSAppListener!

    override func setUpWithError() throws {
        listener = iOSAppListener(controller: mockController)
    }

    override func tearDownWithError() throws {
        listener = nil
    }

    // MARK: startSession

    func test_startSession_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        listener = iOSAppListener(controller: controller!)
        controller = nil

        listener.startSession()

        XCTAssertNil(listener.controller)
    }

    func test_startSession_callsControllerStartSession_andSetsSessionState() {
        listener.startSession()

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSession?.state, .foreground)
    }

    func test_startSession_whenControllerHasCurrentSession_callsEndSession_andThenStartSession() {
        mockController.currentSession = mockController.createSession(state: .foreground)

        listener.startSession()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertNotNil(mockController.currentSession?.state)
        XCTAssertEqual(mockController.currentSession?.state, .foreground)
    }

    func test_startSession_fromBackgroundQueue_callsControllerStartSession_andSetsSessionState() {
        let expectation = self.expectation(description: "startSession")
        DispatchQueue.global().async {
            self.listener.startSession()
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.1, handler: nil)

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertEqual(mockController.currentSession?.state, .foreground)
    }

    // MARK: endSession

    func test_endSession_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        listener = iOSAppListener(controller: controller!)
        controller = nil

        listener.endSession()

        XCTAssertNil(listener.controller)
    }

    func test_endSession_whenControllerHasNoCurrentSession_doesNotCallEndSession() {
        XCTAssertNil(mockController.currentSession)

        listener.endSession()

        XCTAssertFalse(mockController.didCallEndSession)
    }

    func test_endSession_whenControllerHasCurrentSession_callsEndSession() {
        mockController.currentSession = mockController.createSession(state: .foreground)

        listener.endSession()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertFalse(mockController.didCallStartSession)
    }

    // MARK: appDidBecomeActive

    func test_appDidBecomeActive_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        listener = iOSAppListener(controller: controller!)
        controller = nil

        listener.appDidBecomeActive()

        XCTAssertNil(listener.controller)
    }

    func test_appDidBecomeActive_whenControllerHasNoCurrentSession_startsForegroundSession() {
        XCTAssertNil(mockController.currentSession)

        listener.appDidBecomeActive()

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertNotNil(mockController.currentSession)
        XCTAssertEqual(mockController.currentSession?.state, .foreground)
    }

    func test_appDidBecomeActive_whenControllerHasCurrentSession_withStateForeground_doesNothing() {
        let session = mockController.createSession(state: .foreground)
        mockController.currentSession = session

        listener.appDidBecomeActive()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertEqual(session.id, mockController.currentSession!.id)
        XCTAssertEqual(mockController.currentSession?.state, .foreground)
    }

    func test_appDidBecomeActive_whenControllerHasCurrentSession_withColdStartTrue_callsUpdateToForegroundState_andKeepsSameSessionCurrent() {
        let session = mockController.createSession(state: .background)
        session.coldStart = true

        mockController.currentSession = session
        mockController.onUpdateSession { session, state, appTerminated in
            XCTAssertEqual(session.id, self.mockController.currentSession?.id)
            XCTAssertEqual(state, .foreground)
            XCTAssertNil(appTerminated)
        }

        listener.appDidBecomeActive()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertEqual(session.id, mockController.currentSession!.id)

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallUpdateSession)
    }

    func test_appDidBecomeActive_whenControllerHasCurrentSession_withColdStartFalse_createsNewForegroundSession() {
        let session = mockController.createSession(state: .background)
        session.coldStart = false
        mockController.currentSession = session

        listener.appDidBecomeActive()

        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertNotEqual(session.id, mockController.currentSession!.id)
        XCTAssertEqual(mockController.currentSession?.state, .foreground)
    }

    // MARK: appDidEnterBackground

    func test_appDidEnterBackground_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        listener = iOSAppListener(controller: controller!)
        controller = nil

        listener.appDidEnterBackground()

        XCTAssertNil(listener.controller)
    }

    func test_appDidEnterBackground_whenControllerHasNoCurrentSession_startsBackgroundSession() {
        XCTAssertNil(mockController.currentSession)

        listener.appDidEnterBackground()

        XCTAssertNotNil(mockController.currentSession)
        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertEqual(mockController.currentSession?.state, .background)
    }

    func test_appDidEnterBackground_whenControllerHasCurrentSession_withStateBackground_doesNothing() {
        let session = mockController.createSession(state: .background)
        mockController.currentSession = session

        listener.appDidEnterBackground()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertEqual(session.id, mockController.currentSession!.id)
        XCTAssertEqual(mockController.currentSession?.state, .background)
    }

    func test_appDidEnterBackground_whenControllerHasCurrentSession_withStateForeground_createsNewBackgroundSession() {
        let session = mockController.createSession(state: .foreground)
        mockController.currentSession = session

        listener.appDidEnterBackground()

        XCTAssertTrue(mockController.didCallStartSession)
        XCTAssertTrue(mockController.didCallEndSession)
        XCTAssertNotEqual(session.id, mockController.currentSession!.id)
        XCTAssertEqual(mockController.currentSession?.state, .background)
    }

    // MARK: appWillTerminate

    func test_appWillTerminate_whenControllerIsNil_doesNothing() {
        var controller: MockSessionController? = MockSessionController()
        listener = iOSAppListener(controller: controller!)
        controller = nil

        listener.appWillTerminate()

        XCTAssertNil(listener.controller)
    }

    func test_appWillTerminate_whenControllerHasNoCurrentSession_doesNothing() {
        XCTAssertNil(mockController.currentSession)

        listener.appWillTerminate()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
    }

    func test_appWillTerminate_whenControllerHasCurrentForegroundSession_marksItAsAppTerminated() {
        let session = mockController.createSession(state: .foreground)
        session.appTerminated = false
        mockController.currentSession = session

        mockController.onUpdateSession { session, state, appTerminated in
            XCTAssertEqual(session.id, self.mockController.currentSession?.id)
            XCTAssertEqual(appTerminated, true)
            XCTAssertNil(state)
        }

        listener.appWillTerminate()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallUpdateSession)
    }

    func test_appWillTerminate_whenControllerHasCurrentBackgroundSession_marksItAsAppTerminated() {
        let session = mockController.createSession(state: .background)
        session.appTerminated = false
        mockController.currentSession = session

        mockController.onUpdateSession { session, state, appTerminated in
            XCTAssertEqual(session.id, self.mockController.currentSession?.id)
            XCTAssertEqual(appTerminated, true)
            XCTAssertNil(state)
        }

        listener.appWillTerminate()

        XCTAssertFalse(mockController.didCallStartSession)
        XCTAssertFalse(mockController.didCallEndSession)
        XCTAssertTrue(mockController.didCallUpdateSession)
    }

}

#endif
