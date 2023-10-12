//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if os(iOS)
import UIKit

import Foundation
import EmbraceCommon

class iOSSessionLifecyle: SessionLifecycle {

    override var isEnabled: Bool {
        didSet {
            if isEnabled == true {
                onEnabled()
            }
        }
    }

    var currentState: SessionState = .background

    override init(storageInterface: SessionStorageInterface) {
        super.init(storageInterface: storageInterface)

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

        if Thread.isMainThread {
            fetchInitialAppState()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.fetchInitialAppState()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func onEnabled() {
        startNewSession()
    }

    /// Starts a new session if able
    func startNewSession() {
        guard isEnabled == true else {
            return
        }

        // TODO: Check if currentState is enabled in config

        storageInterface.startSession(state: currentState)
        onNewSession?(currentSessionId)
    }

    /// Stops current session and immediately starts a new one if able
    func stopCurrentSession() {
        guard isEnabled == true else {
            return
        }

        let sessionId = currentSessionId
        storageInterface.stopSession()
        onSessionEnded?(sessionId)

        // we always have a session
        startNewSession()
    }

    private func onStateChange(from: SessionState, to: SessionState) {
        guard isEnabled == true, from != to else {
            return
        }

        stopCurrentSession()
    }

    private func fetchInitialAppState() {
        var initialState: SessionState = .background

        if #available(iOS 13.0, tvOS 13.0, *) {
            if let scene = UIApplication.shared.windows.last?.windowScene {
                switch scene.activationState {
                case .foregroundActive, .foregroundInactive: initialState = .foreground
                default: initialState = .background
                }
            }
        } else {
            switch UIApplication.shared.applicationState {
            case .background: initialState = .background
            default: initialState = .foreground
            }
        }

        currentState = initialState
    }

    @objc func appDidBecomeActive() {
        let previousState = currentState
        currentState = .foreground

        onStateChange(from: previousState, to: currentState)
    }

    @objc func appDidEnterBackground() {
        let previousState = currentState
        currentState = .background

        onStateChange(from: previousState, to: currentState)
    }

    @objc func appWillTerminate() {
        // TODO: Flag session as terminated
        storageInterface.stopSession()
    }
}

#endif
