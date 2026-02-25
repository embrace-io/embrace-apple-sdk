//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// Implemented by `EmbraceOTelBridge` to give `EmbraceSpanProcessor` a way to:
/// 1. Ask whether a span was created internally (outbound) so it can be skipped.
/// 2. Receive inbound span lifecycle events.
package protocol EmbraceSpanProcessorDelegate: AnyObject {

    /// Returns `true` if the span was created by the bridge itself (outbound signal).
    /// Inbound spans (from external OTel tracers) return `false`.
    func isInternalSpan(_ span: ReadableSpan) -> Bool

    /// Called when an external OTel span is started.
    func onExternalSpanStarted(_ span: ReadableSpan)

    /// Called when an external OTel span is ended.
    func onExternalSpanEnded(_ span: ReadableSpan)

    /// The foreground/background state of the current session.
    var currentSessionState: SessionState { get }

    /// The identifier for the current session, or `nil` when no session is active.
    var currentSessionId: EmbraceIdentifier? { get }
}
