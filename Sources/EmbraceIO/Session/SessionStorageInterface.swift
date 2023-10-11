//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

class SessionStorageInterface {
    let storage: EmbraceStorage?
    var sessionRecord: SessionRecord?
    private(set) var currentSessionId: SessionId?

    
    init(storage: EmbraceStorage?) {
        self.storage = storage
    }

    func startSession(state: SessionState) {
        currentSessionId = UUID().uuidString

        if let newSessionId = currentSessionId {
            sessionRecord = SessionRecord(id: newSessionId, state: state, startTime: Date())
            storage?.upsertSessionAsync(sessionRecord!) { result in
                switch result {
                case .success(let session):
                    // TODO: send session start message
                    print("Session \(session.id) started!")
                case .failure(let error):
                    // TODO: decide what to do here
                    print("Session \(newSessionId) start failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func stopSession() {
        if let endedSessionId = currentSessionId {
            sessionRecord?.endTime = Date()
            storage?.upsertSessionAsync(sessionRecord!) { result in
                switch result {
                case .success(let session):
                    // TODO: send finished session
                    print("Session \(session.id) finished!")
                    
                case .failure(let error):
                    // TODO: decide what to do here
                    print("Session \(endedSessionId) finish failed: \(error.localizedDescription)")
                }
            }
        }

        currentSessionId = nil
    }
}
