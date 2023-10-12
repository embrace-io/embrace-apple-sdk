//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import UIKit
#endif

import Foundation
import EmbraceCommon

class ManualSessionLifecyle: SessionLifecycle {
    
    override var isEnabled: Bool {
        didSet {
            if isEnabled == true {
                onEnabled()
            }
        }
    }
    
    func startNewSession() {
        guard isEnabled == true else {
            return
        }

#if canImport(UIKit)
        let currentState = UIApplication.shared.applicationState
        let sessionState = SessionState(appState: currentState)!
        storageInterface.startSession(state: sessionState)
        onNewSession?(currentSessionId)
#else
        storageInterface.startSession(state: .foreground)
        onNewSession?(currentSessionId)
#endif
    }
    
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
    
    func onEnabled() {
        startNewSession()
    }
}
