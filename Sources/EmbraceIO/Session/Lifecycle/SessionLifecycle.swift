//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

typealias SessionLifecycle = SessionLifecycleBase & SessionLifecycleProtocol

protocol SessionLifecycleProtocol {
    var isEnabled: Bool { get set }
    var currentSessionId: SessionId? { get }

    func startNewSession()
    func stopCurrentSession()
}

class SessionLifecycleBase {
    let storageInterface: SessionStorageInterface

    var isEnabled: Bool = false

    var currentSessionId: SessionId? {
        return storageInterface.currentSessionId
    }

    init(storageInterface: SessionStorageInterface) {
        self.storageInterface = storageInterface
    }
}
