//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

#if os(iOS) || os(tvOS)

    /// Records whether the session controller had already been driven at the moment it was notified.
    ///
    /// The ordering is the whole reason `AppStateObserver` exists: a state that must record into the
    /// *outgoing* session part has to hear about backgrounding before that part is closed, and a
    /// state that belongs to the *incoming* part has to hear about foregrounding after it starts.
    private final class SpyAppStateObserver: AppStateObserver {

        private let controller: MockSessionController

        private(set) var backgroundCalls: [(sessionEnded: Bool, sessionStarted: Bool)] = []
        private(set) var foregroundCalls: [(sessionEnded: Bool, sessionStarted: Bool)] = []

        init(controller: MockSessionController) {
            self.controller = controller
        }

        func appWillBackground(at time: Date) {
            backgroundCalls.append((controller.didCallEndSession, controller.didCallStartSession))
        }

        func appDidForeground(at time: Date) {
            foregroundCalls.append((controller.didCallEndSession, controller.didCallStartSession))
        }
    }

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

        // MARK: - AppStateObserver ordering

        func test_appWillBackground_isNotifiedBeforeTheSessionIsTouched() {
            let spy = SpyAppStateObserver(controller: mockController)
            lifecycle.setAppStateObserver(spy)

            lifecycle.appDidEnterBackground()

            // The outgoing part must still be open. If this call moved below the controller work,
            // the "Backgrounded" transition would land after its state span closed and be counted
            // as having happened outside a session.
            XCTAssertEqual(spy.backgroundCalls.count, 1)
            XCTAssertFalse(spy.backgroundCalls[0].sessionStarted)
            XCTAssertFalse(spy.backgroundCalls[0].sessionEnded)
        }

        func test_appDidForeground_isNotifiedAfterTheSessionIsStarted() {
            mockController.currentSession = nil
            let spy = SpyAppStateObserver(controller: mockController)
            lifecycle.setAppStateObserver(spy)

            lifecycle.appDidBecomeActive()

            // The incoming part must already exist, so whatever this records belongs to it.
            XCTAssertEqual(spy.foregroundCalls.count, 1)
            XCTAssertTrue(spy.foregroundCalls[0].sessionStarted)
        }

        func test_appDidForeground_isNotifiedEvenWhenNoSessionWorkHappens() {
            // The `defer` exists for this: an already-foreground app, a cold start inside the launch
            // grace period, and a nil/inactive controller are all still foregrounds the observer
            // needs to hear about. A trailing call would silently skip every one of them.
            let controllerless = iOSSessionLifecycle(controller: MockSessionController())
            controllerless.stop()
            let spy = SpyAppStateObserver(controller: mockController)
            controllerless.setAppStateObserver(spy)

            controllerless.appDidBecomeActive()

            XCTAssertEqual(spy.foregroundCalls.count, 1)
        }

        func test_appStateObserver_isHeldWeakly() {
            var spy: SpyAppStateObserver? = SpyAppStateObserver(controller: mockController)
            lifecycle.setAppStateObserver(spy)
            spy = nil

            // The registrant owns the observer's lifetime; the lifecycle must not keep it alive.
            // Reaching here without a crash and with nothing recorded is the assertion.
            lifecycle.appDidEnterBackground()
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

        func test_startSession_fromNonMainThread_callsControllerStartSession_andSetsSessionState() {
            let expectation = XCTestExpectation(description: "startSession called off the main thread")
            // Use a dedicated thread instead of DispatchQueue.global: the global concurrent pool is
            // a bounded, shared resource that can be exhausted under CI load, starving this block so
            // the timeout flakes — which was a recurring source of CI failures here. A detached
            // thread is always scheduled.
            Thread.detachNewThread { [self] in
                XCTAssertFalse(Thread.isMainThread)
                lifecycle.startSession()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: .longTimeout)
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

        func test_appDidBecomeActive_hasCurrentSession_coldStartTrue_gracePeriodTrue_callsUpdateToForegroundState_keepsSameSession() {
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

        func test_appDidBecomeActive_hasCurrentSession_coldStartTrue_gracePeriodFalse_startsNewForegroundSession() {
            lifecycle = iOSSessionLifecycle(controller: mockController, launchGracePeriod: 0)
            lifecycle.setup()

            mockController.nextSessionColdStart = true
            mockController.startSession(state: .background)

            let session = mockController.currentSession
            mockController.didCallStartSession = false

            lifecycle.appDidBecomeActive()

            XCTAssertNotEqual(session!.id, mockController.currentSession!.id)
            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertTrue(mockController.didCallEndSession)
            XCTAssertEqual(mockController.currentSession!.state, .foreground)
            XCTAssertFalse(mockController.didCallUpdateSession)
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
