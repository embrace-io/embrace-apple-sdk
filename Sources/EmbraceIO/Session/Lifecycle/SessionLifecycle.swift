//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon

typealias SessionLifecycle = SessionLifecycleBase & SessionLifecycleProtocol

protocol SessionLifecycleProtocol {
    var isEnabled: Bool { get set }
    var currentSessionId: SessionId? { get }

    var onNewSession: ((SessionId?) -> Void)? { get set }
    var onSessionEnded: ((SessionId?) -> Void)? { get set }

    func startNewSession()
    func stopCurrentSession()
}

class SessionLifecycleBase {
    let storageInterface: SessionStorageInterface

    var isEnabled: Bool = false

    var currentSessionId: SessionId? {
        return storageInterface.currentSessionId
    }

    var onNewSession: ((SessionId?) -> Void)?
    var onSessionEnded: ((SessionId?) -> Void)?

    init(storageInterface: SessionStorageInterface) {
        self.storageInterface = storageInterface
    }
}
