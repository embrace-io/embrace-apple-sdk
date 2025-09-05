//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if os(iOS)
    import Foundation
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif
    import UIKit

    // ignoring linting rule to have a lowercase letter first on the class name
    // since we want to use 'iOS'...

    final class iOSSessionLifecycle: SessionLifecycle {

        var active: Bool = false
        weak var controller: SessionControllable?
        var currentState: SessionState = .background

        init(controller: SessionControllable) {
            self.controller = controller
            listenForUIApplication()
        }

        func setup() {
            // only fetch the app state once during setup
            // MUST BE DONE ON THE MAIN THREAD!!!
            guard Thread.isMainThread else {
                return
            }

            let appState = UIApplication.shared.applicationState
            currentState = appState == .background ? .background : .foreground

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
        }

        /// Application state is now in foreground
        @objc func appDidBecomeActive() {
            currentState = .foreground

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

                if currentSession.coldStart {
                    // check if current session is cold start
                    // flip state to foreground if so
                    controller.update(state: .foreground)
                } else {
                    // if not cold start, end current background session
                    // start a new foreground session
                    controller.startSession(state: .foreground)
                }

            } else {
                // create initial session marked as foreground
                controller.startSession(state: .foreground)
            }
        }

        /// Application state is now in the background
        @objc func appDidEnterBackground() {
            currentState = .background

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
