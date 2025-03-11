//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal

/// Protocol for managing sessions.
/// See ``SessionController`` for main conformance
protocol SessionControllable: AnyObject {

    var currentSessionId: SessionIdentifier? { get }
    var currentSessionState: SessionState? { get }
    var currentSessionColdStart: Bool? { get }

    @discardableResult
    func startSession(state: SessionState) -> SessionIdentifier?

    @discardableResult
    func endSession() -> Date

    func update(state: SessionState)
    func update(appTerminated: Bool)

    var attachmentCount: Int { get }
    func increaseAttachmentCount()

    func clear()
}
