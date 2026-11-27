//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// How a screen load ended. Mirrors Android's `ScreenLoadOutcome`.
enum ScreenLoadOutcome {
    /// The destination settled. Never produced on iOS until settle detection exists.
    case settled

    /// The load ended at the first frame after navigation end, or at navigation end when no frame
    /// arrived within the timeout. Android reports its first-frame fallback with this outcome, so it is
    /// iOS's normal outcome.
    case timedOut

    /// The user tapped again after navigation end, before the load completed. The load ends at its
    /// last activity, not the tap.
    case userInterrupted

    /// A new navigation started after navigation end, before the load completed. The load ends at its
    /// last activity, and a fresh load opens for the new destination.
    case navigationInterrupted

    /// The value written to ``SpanSemantics/ScreenLoad/keyOutcome``.
    var wireValue: String {
        switch self {
        case .settled: SpanSemantics.ScreenLoad.outcomeSettled
        case .timedOut: SpanSemantics.ScreenLoad.outcomeTimedOut
        case .userInterrupted: SpanSemantics.ScreenLoad.outcomeUserInterrupted
        case .navigationInterrupted: SpanSemantics.ScreenLoad.outcomeNavigationInterrupted
        }
    }
}
