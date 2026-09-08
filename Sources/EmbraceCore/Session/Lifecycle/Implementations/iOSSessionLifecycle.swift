//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(watchOS)
    import Foundation
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif
    #if os(watchOS)
        import WatchKit
    #else
        import UIKit
    #endif

    // ignoring linting rule to have a lowercase letter first on the class name
    // since we want to use 'iOS'...

    final class iOSSessionLifecycle: SessionLifecycle {

        var active: Bool = false
        weak var controller: SessionControllable?
        var currentState: SessionState = .background

        private weak var appStateObserver: AppStateObserver?

        func setAppStateObserver(_ observer: AppStateObserver?) {
            appStateObserver = observer
        }
        let launchGracePeriod: TimeInterval

        init(controller: SessionControllable, launchGracePeriod: TimeInterval = 5.0) {
            self.controller = controller
            self.launchGracePeriod = launchGracePeriod

            listenForUIApplication()
        }

        func setup() {
            // only fetch the app state once during setup
            // MUST BE DONE ON THE MAIN THREAD!!!
            guard Thread.isMainThread else {
                return
            }

            #if os(watchOS)
                currentState = .unknown
            #else
                let appState = UIApplication.shared.applicationState
                currentState = appState == .background ? .background : .foreground
            #endif

            active = true
        }

        func stop() {
            active = false
        }

        func startSession() {
            guard active else {
                return
            }

            controller?.startSession(state: currentState)
        }

        func endSession() {
            guard active else {
                return
            }

            // there's always an active session!
            // starting a new session will end the current one (if any)
            controller?.startSession(state: currentState)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }

    extension iOSSessionLifecycle {

        private func listenForUIApplication() {
            #if os(watchOS)
                if #available(watchOS 7.0, *) {
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(appDidBecomeActive),
                        name: WKExtension.applicationDidBecomeActiveNotification,
                        object: nil
                    )

                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(appDidEnterBackground),
                        name: WKExtension.applicationDidEnterBackgroundNotification,
                        object: nil
                    )

                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(appWillTerminate),
                        name: WKExtension.applicationWillResignActiveNotification,
                        object: nil
                    )
                }
            #else
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(appDidBecomeActive),
                    name: UIApplication.didBecomeActiveNotification,
                    object: nil
                )

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(appDidEnterBackground),
                    name: UIApplication.didEnterBackgroundNotification,
                    object: nil
                )

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(appWillTerminate),
                    name: UIApplication.willTerminateNotification,
                    object: nil
                )
            #endif
        }

        /// Application state is now in foreground
        @objc func appDidBecomeActive() {
            let now = Date()
            currentState = .foreground

            // Deferred so it lands *after* the session work below: when foregrounding starts a new
            // part, what is recorded here belongs to that part rather than the one being closed.
            // (Not every path starts one — see the early returns below.)
            // `defer` rather than a trailing call because every early return below is also a
            // foreground the observer needs to hear about.
            defer {
                appStateObserver?.appDidForeground(at: now)
            }

            guard let controller = controller,
                active
            else {
                return
            }

            if let currentSession = controller.currentSession {

                if currentSession.state == .foreground {
                    // if current session is already foreground, do nothing
                    return
                }

                if currentSession.coldStart && Date().timeIntervalSince(currentSession.startTime) <= launchGracePeriod {
                    // if this is the first session and we're still
                    // inside the launch grace period
                    // swap the session state to foreground and keep it
                    controller.update(state: .foreground)

                } else {
                    // otherwise just start a new foreground session
                    // and end the current background session
                    // (if the config is disabled, the background session
                    // should be dropped and not be sent)
                    controller.startSession(state: .foreground)
                }

            } else {
                // create initial session marked as foreground
                controller.startSession(state: .foreground)
            }
        }

        /// Application state is now in the background
        @objc func appDidEnterBackground() {
            let now = Date()
            currentState = .background

            // Called *before* the session work below, which is the whole point of this seam: the
            // outgoing part is still open here, so an observer can still record into it. Anything
            // downstream — the notifications `SessionController` posts, `onSessionWillEnd` — runs
            // after the part's spans have already been closed.
            appStateObserver?.appWillBackground(at: now)

            guard let controller = controller,
                active
            else {
                return
            }

            // if current session is already background, do nothing
            if let currentSession = controller.currentSession,
                currentSession.state == .background
            {
                return
            }

            // start new background session
            controller.startSession(state: .background)
        }

        /// User has terminated the app. This will not end the current session as the app
        /// will continue to run until the system kills it.
        /// This session will not be marked as a "clean exit".
        @objc func appWillTerminate() {
            controller?.update(appTerminated: true)
        }
    }

#endif
