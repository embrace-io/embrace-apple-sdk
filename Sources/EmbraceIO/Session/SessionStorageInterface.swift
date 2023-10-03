//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

class SessionStorageInterface {
    let storage: EmbraceStorage?
    private(set) var currentSessionId: SessionId?

    init(storage: EmbraceStorage?) {
        self.storage = storage
    }

    func startSession(state: SessionState) {
        currentSessionId = UUID().uuidString

        if let newSessionId = currentSessionId {
            storage?.addSessionAsync(id: newSessionId, state: state.rawValue, startTime: Date(), endTime: nil) { result in
                switch result {
                case .success(let session):
                    // TODO: send session start message
                    print("Session \(session.id) finished!")
                case .failure(let error):
                    // TODO: decide what to do here
                    print("Session \(newSessionId) finish failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func stopSession() {
        if let endedSessionId = currentSessionId {
            storage?.updateSessionEndTimeAsync(id: endedSessionId, endTime: Date()) { result in
                switch result {
                case .success(let session):
                    if let session = session {
                        // TODO: send finished session
                        print("Session \(session.id) finished!")
                    }
                case .failure(let error):
                    // TODO: decide what to do here
                    print("Session \(endedSessionId) finish failed: \(error.localizedDescription)")
                }
            }
        }

        currentSessionId = nil
    }
}
