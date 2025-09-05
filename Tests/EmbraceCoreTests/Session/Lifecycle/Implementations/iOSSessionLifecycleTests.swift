//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import XCTest

@testable import EmbraceCore

#if os(iOS)

    final class iOSSessionLifecycleTests: XCTestCase {

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
            XCTAssertEqual(mockController.currentSession?.state, .foreground)
        }

        func test_startSession_whenControllerHasCurrentSession_callsEndSession_andThenStartSession() {
            mockController.startSession(state: .foreground)

            lifecycle.startSession()

            XCTAssertTrue(mockController.didCallEndSession)
            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertNotNil(mockController.currentSession?.state)
            XCTAssertEqual(mockController.currentSession?.state, .foreground)
        }

        @MainActor
        func test_startSession_fromBackgroundQueue_callsControllerStartSession_andSetsSessionState() async {

            await Task.detached {
                self.lifecycle.startSession()
            }.value
            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertEqual(mockController.currentSession?.state, .foreground)
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
            XCTAssertNil(mockController.currentSession)

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
            XCTAssertNil(mockController.currentSession)

            lifecycle.appDidBecomeActive()

            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertNotNil(mockController.currentSession)
            XCTAssertEqual(mockController.currentSession?.state, .foreground)
        }

        func test_appDidBecomeActive_hasCurrentSession_withStateForeground_doesNothing() {
            mockController.startSession(state: .foreground)
            let session = mockController.currentSession
            mockController.didCallStartSession = false

            lifecycle.appDidBecomeActive()

            XCTAssertFalse(mockController.didCallStartSession)
            XCTAssertEqual(session!.id, mockController.currentSession!.id)
            XCTAssertEqual(mockController.currentSession?.state, .foreground)
        }

        func test_appDidBecomeActive_hasCurrentSession_coldStartTrue_callsUpdateToForegroundState_keepsSameSession() {
            mockController.nextSessionColdStart = true
            mockController.startSession(state: .background)

            let session = mockController.currentSession
            mockController.didCallStartSession = false

            mockController.onUpdateSession { session, state, appTerminated in
                XCTAssertEqual(session?.id, self.mockController.currentSession?.id)
                XCTAssertEqual(state, .foreground)
                XCTAssertNil(appTerminated)
            }

            lifecycle.appDidBecomeActive()

            XCTAssertEqual(session!.id, mockController.currentSession!.id)
            XCTAssertFalse(mockController.didCallStartSession)
            XCTAssertFalse(mockController.didCallEndSession)
            XCTAssertTrue(mockController.didCallUpdateSession)
        }

        func test_appDidBecomeActive_hasCurrentSession_withColdStartFalse_createsNewForegroundSession() {
            mockController.nextSessionColdStart = false
            mockController.startSession(state: .background)

            let session = mockController.currentSession

            lifecycle.appDidBecomeActive()

            XCTAssertTrue(mockController.didCallEndSession)
            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertNotEqual(session!.id, mockController.currentSession!.id)
            XCTAssertEqual(mockController.currentSession?.state, .foreground)
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
            XCTAssertNil(mockController.currentSession)

            lifecycle.appDidEnterBackground()

            XCTAssertNotNil(mockController.currentSession)
            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertFalse(mockController.didCallEndSession)
            XCTAssertEqual(mockController.currentSession?.state, .background)
        }

        func test_appDidEnterBackground_hasCurrentSession_withStateBackground_doesNothing() {
            mockController.startSession(state: .background)
            let session = mockController.currentSession
            mockController.didCallStartSession = false

            lifecycle.appDidEnterBackground()

            XCTAssertFalse(mockController.didCallStartSession)
            XCTAssertFalse(mockController.didCallEndSession)
            XCTAssertEqual(session!.id, mockController.currentSession!.id)
            XCTAssertEqual(mockController.currentSession?.state, .background)
        }

        func test_appDidEnterBackground_hasCurrentSession_withStateForeground_createsNewBackgroundSession() {
            mockController.startSession(state: .foreground)
            let session = mockController.currentSession

            lifecycle.appDidEnterBackground()

            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertTrue(mockController.didCallEndSession)
            XCTAssertNotEqual(session!.id, mockController.currentSession!.id)
            XCTAssertEqual(mockController.currentSession?.state, .background)
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
            XCTAssertNil(mockController.currentSession)

            lifecycle.appWillTerminate()

            XCTAssertFalse(mockController.didCallStartSession)
            XCTAssertFalse(mockController.didCallEndSession)
        }

        func test_appWillTerminate_hasCurrentForegroundSession_marksItAsAppTerminated() {
            mockController.nextSessionAppTerminated = false
            mockController.startSession(state: .foreground)

            mockController.onUpdateSession { session, state, appTerminated in
                XCTAssertEqual(session?.id, self.mockController.currentSession?.id)
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
            mockController.nextSessionAppTerminated = false
            mockController.startSession(state: .background)

            mockController.onUpdateSession { session, state, appTerminated in
                XCTAssertEqual(session?.id, self.mockController.currentSession?.id)
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
