//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if os(iOS)
import Foundation
import EmbraceCommon
import UIKit

final class iOSAppListener: SessionListener {

    weak var controller: SessionControllable?

    init(controller: SessionControllable) {
        self.controller = controller
        listenForUIApplication()
    }

    func startSession() {
        guard let controller = controller else { return }

        if let currentSession = controller.currentSession {
            controller.end(session: currentSession)
        }

        let newSession = controller.createSession(state: determineSessionState())
        controller.start(session: newSession)
    }

    func endSession() {
        guard let controller = controller else { return }
        guard let currentSession = controller.currentSession else {
            return
        }

        controller.end(session: currentSession)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension iOSAppListener {

    /// This method will retrieve a SessionState by checking the current UIApplication.applicationState
    /// This
    /// - Returns: The current SessionState at the current moment in time
    private func determineSessionState() -> SessionState {

        let applicationState: UIApplication.State
        if Thread.isMainThread {
            applicationState = UIApplication.shared.applicationState
        } else {
            applicationState = DispatchQueue.main.sync {
                UIApplication.shared.applicationState
            }
        }

        switch applicationState {
        case .active, .inactive:
            return .foreground
        case .background:
            return .background
        @unknown default:
            return .foreground
        }
    }

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
        guard let controller = controller else { return }

        if let currentSession = controller.currentSession {
            if currentSession.state == .foreground {
                // if current session is already foreground, do nothing
                return
            }

            if currentSession.coldStart {
                // check if current session is cold start
                // flip state to foreground if so
                controller.update(session: currentSession, state: .foreground)
            } else {
                // if not cold start, end current background session
                // start a new foreground session
                controller.end(session: currentSession)

                let newSession = controller.createSession(state: .foreground)
                controller.start(session: newSession)
            }

        } else {
            // create initial session marked as foreground
            let initialSession = controller.createSession(state: .foreground)
            controller.start(session: initialSession)
        }
    }

    /// Application state is now in the background
    @objc func appDidEnterBackground() {
        guard let controller = controller else { return }

        if let currentSession = controller.currentSession {
            if currentSession.state == .background {
                // if current session is already background, do nothing
                return
            }

            // end current foreground session
            // start a new background session
            controller.end(session: currentSession)

            let newSession = controller.createSession(state: .background)
            controller.start(session: newSession)
        } else {
            // create initial session marked as background
            let initialSession = controller.createSession(state: .background)
            controller.start(session: initialSession)
        }
    }

    /// User has terminated the app. This will not end the current session as the app
    /// will continue to run until the system kills it.
    /// This session will not be marked as a "clean exit".
    @objc func appWillTerminate() {
        guard let controller = controller else { return }

        if let currentSession = controller.currentSession {
            controller.update(session: currentSession, appTerminated: true)
        }
    }
}

#endif
