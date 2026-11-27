//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// A completed screen-load measurement: the time from the initial interaction until the destination
/// screen loaded. Mirrors Android's `ScreenLoadResult`.
struct ScreenLoadResult: Equatable {
    /// Wall-clock start of the load, typically the tap that triggered the navigation.
    let startTime: Date

    /// Load duration (initial interaction to end), in milliseconds.
    let durationMs: Int

    /// The destination screen name (last writer wins between navigation start and end).
    let screenName: String

    /// How the load ended.
    let outcome: ScreenLoadOutcome

    /// Duration from ``startTime`` until the navigation start that confirmed this as a screen load.
    let navStartDelayMs: Int

    /// Duration from navigation start until navigation end, i.e. how long the navigation itself took.
    let navDurationMs: Int

    /// Duration from navigation end until the first frame rendered on the destination, or `0` if no
    /// frame arrived before the load completed.
    let firstFrameDurationMs: Int

    /// The idle threshold that was applied to determine when the destination had settled. Always `0`
    /// on iOS, which has no settle detection yet.
    let idleThresholdMs: Int

    /// The maximum duration that was applied before the load was force-reported as timed out.
    let timeoutMs: Int

    /// The maximum tap-to-navigation-start gap that was applied to link the two into one load.
    let navTimeoutMs: Int

    /// The span attributes for this result, keyed as Android keys them.
    var attributes: [String: String] {
        [
            SpanSemantics.View.keyViewName: screenName,
            SpanSemantics.ScreenLoad.keyOutcome: outcome.wireValue,
            SpanSemantics.ScreenLoad.keyNavStartDelayMs: String(navStartDelayMs),
            SpanSemantics.ScreenLoad.keyNavDurationMs: String(navDurationMs),
            SpanSemantics.ScreenLoad.keyFirstFrameDurationMs: String(firstFrameDurationMs),
            SpanSemantics.ScreenLoad.keyIdleThresholdMs: String(idleThresholdMs),
            SpanSemantics.ScreenLoad.keyTimeoutMs: String(timeoutMs),
            SpanSemantics.ScreenLoad.keyNavTimeoutMs: String(navTimeoutMs)
        ]
    }
}
