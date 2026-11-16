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
/// Every attribute write is persisted, so the values aren't written to the session part's span on every call.
/// They're written once `flushCallCount` calls are pending, `flushInterval` seconds after the first pending call,
/// and when `flush()` is called as the session part ends. They start over when a new session part starts.
final class SlowCallbackRecorder {

    static let flushCallCount = 5
    static let flushInterval: TimeInterval = 5

    private struct Stats {
        var count = 0
        var maxMs = 0
    }

    private struct State {
        var sessionSpan: EmbraceSpan?
        var stats: [SlowCallback: Stats] = [:]
        var pending: Set<SlowCallback> = []
        var pendingCallCount = 0
        var isFlushScheduled = false
    }

    private let currentSessionSpan: () -> EmbraceSpan?
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private let state = EmbraceMutex(State())

    /// - Parameters:
    ///   - currentSessionSpan: Returns the span of the current session part, if there is one.
    ///     It's called under the recorder's lock, so it must not call back into the recorder.
    ///   - schedule: Runs the block after the given number of seconds.
    init(
        currentSessionSpan: @escaping () -> EmbraceSpan?,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, block in
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: block)
        }
    ) {
        self.currentSessionSpan = currentSessionSpan
        self.schedule = schedule
    }

    /// Records a slow call to `callback` that took `duration` seconds.
    /// The call counts toward the current session part, and is dropped if there's none.
    func recordSlowCall(_ callback: SlowCallback, duration: TimeInterval) {
        let ms = Int(max(duration, 0) * 1000)

        let shouldSchedule = state.withLock { state -> Bool in
            // Read under the lock, so calls see the session parts in the order they apply their changes.
            // Otherwise a call that read the previous part's span could take the lock after one that read
            // the new part's, and reset the new part's values.
            guard let span = currentSessionSpan() else {
                return false
            }

            // Calls still pending for an earlier session part are dropped: its span has already been uploaded.
            if state.sessionSpan?.context.spanId != span.context.spanId {
                state = State(sessionSpan: span, isFlushScheduled: state.isFlushScheduled)
            }

            var stats = state.stats[callback] ?? Stats()
            stats.count += 1
            stats.maxMs = max(stats.maxMs, ms)
            state.stats[callback] = stats
            state.pending.insert(callback)
            state.pendingCallCount += 1

            if state.pendingCallCount >= Self.flushCallCount {
                Self.write(&state)
                return false
            }

            guard state.isFlushScheduled == false else {
                return false
            }
            state.isFlushScheduled = true
            return true
        }

        if shouldSchedule {
            schedule(Self.flushInterval) { [weak self] in
                self?.state.withLock { state in
                    state.isFlushScheduled = false
                    Self.write(&state)
                }
            }
        }
    }

    /// Writes the pending values to the session part's span.
    func flush() {
        state.withLock { Self.write(&$0) }
    }

    /// Runs under the lock, so concurrent writes can't land out of order.
    private static func write(_ state: inout State) {
        guard let span = state.sessionSpan else {
            return
        }

        for callback in state.pending {
            guard let stats = state.stats[callback] else {
                continue
            }
            SessionSpanUtils.setSlowCallback(span: span, callback: callback, count: stats.count, maxMs: stats.maxMs)
        }

        state.pending = []
        state.pendingCallCount = 0
    }
}
