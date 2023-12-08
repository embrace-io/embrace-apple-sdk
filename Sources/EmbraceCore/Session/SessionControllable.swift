//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

/// Protocol for managing sessions.
/// See ``SessionController`` for main conformance
protocol SessionControllable: AnyObject {

    var currentSession: SessionRecord? { get }

    @discardableResult
    func startSession(state: SessionState) -> SessionRecord

    @discardableResult
    func endSession() -> Date

    func update(state: SessionState)
    func update(appTerminated: Bool)
}
