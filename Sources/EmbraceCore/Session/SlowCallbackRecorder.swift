//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// An app callback whose slow calls are reported, named by the session span attributes that report them.
struct SlowCallback: Hashable {
    let countKey: String
    let maxMsKey: String

    static let networkSpanParentProvider = SlowCallback(
        countKey: SpanSemantics.Session.keySlowNetworkSpanParentProviderCount,
        maxMsKey: SpanSemantics.Session.keySlowNetworkSpanParentProviderMaxMs
    )
}

/// Counts slow calls to app callbacks during the current session part, along with the longest one.
///
/// Both values are written to the session part's span on every slow call, not only when the part ends,
/// so a part that ends in a crash or a kill keeps them. They start over when a new session part starts.
final class SlowCallbackRecorder {

    private struct Stats {
        var count = 0
        var maxMs = 0
    }

    private struct State {
        var sessionSpanId: String?
        var stats: [SlowCallback: Stats] = [:]
    }

    private let currentSessionSpan: () -> EmbraceSpan?
    private let state = EmbraceMutex(State())

    init(currentSessionSpan: @escaping () -> EmbraceSpan?) {
        self.currentSessionSpan = currentSessionSpan
    }

    /// Records a slow call to `callback` that took `duration` seconds.
    /// The call counts toward the current session part, and is dropped if there's none.
    func recordSlowCall(_ callback: SlowCallback, duration: TimeInterval) {
        guard let span = currentSessionSpan() else {
            return
        }

        let ms = Int(max(duration, 0) * 1000)

        // The span is updated under the lock, so concurrent calls can't write their values out of order.
        state.withLock { state in
            if state.sessionSpanId != span.context.spanId {
                state = State(sessionSpanId: span.context.spanId)
            }

            var stats = state.stats[callback] ?? Stats()
            stats.count += 1
            stats.maxMs = max(stats.maxMs, ms)
            state.stats[callback] = stats

            SessionSpanUtils.setSlowCallback(span: span, callback: callback, count: stats.count, maxMs: stats.maxMs)
        }
    }
}
