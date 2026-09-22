//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Custom OTel `IdGenerator` that lets the bridge pre-reserve the span ID the SDK is about to
/// assign, so the bridge can recognize its own spans in `SpanProcessor.onStart` — which the SDK
/// fires synchronously inside `startSpan()`, before the span's ID is otherwise knowable.
///
/// The reservation is consumed synchronously, on the reserving thread, by the `generateSpanId()`
/// call that `startSpan()` makes. It is stored per thread so that concurrent span creation — by
/// the bridge or by any other holder of a tracer from the same provider — cannot cross wires: a
/// thread with no reservation of its own always draws a fresh random ID and never waits.
///
/// Usage:
/// 1. Call `withReservation(_:)`, which reserves the ID the OTel SDK will assign to the next span
///    created on this thread.
/// 2. Inside the closure, register that ID in the bridge's `pendingSpanIds` set and call
///    `builder.startSpan()` — the SDK calls `generateSpanId()` synchronously, which returns the
///    reserved ID.
/// 3. When `EmbraceSpanProcessor.onStart` fires, `pendingSpanIds` already contains the ID so
///    `isInternalSpan` correctly returns `true`.
final class EmbraceSpanIdGenerator: IdGenerator {

    private let inner = RandomIdGenerator()

    /// Reservations in flight, keyed by the thread that made them. The mutex guards only this
    /// map and is never held across a call into the OpenTelemetry SDK.
    private let reservations = EmbraceMutex([UInt64: SpanId]())

    private var currentThreadId: UInt64 {
        var threadId: UInt64 = 0
        pthread_threadid_np(nil, &threadId)
        return threadId
    }

    // MARK: - Reservation

    /// Reserves the `SpanId` the OTel SDK will assign to the next span created on this thread,
    /// for the duration of `body`. The reservation is visible only to the calling thread and is
    /// always released when `body` returns.
    /// - Parameter body: Closure that creates the span, receiving the reserved `SpanId`.
    /// - Returns: Whatever `body` returns.
    func withReservation<T>(_ body: (SpanId) throws -> T) rethrows -> T {
        let threadId = currentThreadId
        let spanId = inner.generateSpanId()

        reservations.withLock { $0[threadId] = spanId }
        defer { reservations.withLock { $0[threadId] = nil } }

        return try body(spanId)
    }

    // MARK: - IdGenerator

    /// Returns this thread's reservation if it has one; otherwise generates a fresh random ID.
    func generateSpanId() -> SpanId {
        let threadId = currentThreadId

        if let reserved = reservations.withLock({ $0.removeValue(forKey: threadId) }) {
            return reserved
        }

        return inner.generateSpanId()
    }

    func generateTraceId() -> TraceId {
        inner.generateTraceId()
    }
}
