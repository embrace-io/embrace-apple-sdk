//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// Implemented by `EmbraceOTelBridge` to give `EmbraceLogProcessor` a way to:
/// 1. Ask whether a log was emitted internally (outbound) so it can be skipped.
/// 2. Receive inbound log events.
package protocol EmbraceLogProcessorDelegate: AnyObject {

    /// Returns `true` if the log was emitted by the bridge itself (outbound signal).
    /// Inbound logs (from external OTel loggers) return `false`.
    func isInternalLog(_ log: ReadableLogRecord) -> Bool

    /// Called when an external OTel log is emitted.
    func onExternalLogEmitted(_ log: ReadableLogRecord)

    /// The foreground/background state of the current session.
    var currentSessionState: SessionState { get }

    /// The identifier for the current session, or `nil` when no session is active.
    var currentSessionId: EmbraceIdentifier? { get }
}
