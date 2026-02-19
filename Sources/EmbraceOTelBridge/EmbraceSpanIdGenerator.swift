//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Custom OTel `IdGenerator` that allows the bridge to pre-reserve a span ID before calling
/// `builder.startSpan()`. This eliminates the need for a thread-local flag to suppress
/// inbound callbacks during span creation.
///
/// Usage:
/// 1. Call `reserveNextSpanId()` to obtain the ID that the OTel SDK will assign to the next span.
/// 2. Register that ID in the bridge's `pendingSpanIds` set.
/// 3. Call `builder.startSpan()` — the SDK calls `generateSpanId()` synchronously, which
///    returns the pre-reserved ID.
/// 4. When `EmbraceSpanProcessor.onStart` fires, `pendingSpanIds` already contains the ID so
///    `isInternalSpan` correctly returns `true`.
final class EmbraceSpanIdGenerator: IdGenerator {

    private let inner = RandomIdGenerator()
    private let reservedSpanId = EmbraceMutex<SpanId?>(nil)

    // MARK: - Reservation

    /// Generates and pre-reserves the `SpanId` for the next span the OTel SDK will create.
    /// Must be called immediately before `builder.startSpan()`.
    func reserveNextSpanId() -> SpanId {
        let spanId = inner.generateSpanId()
        reservedSpanId.withLock { $0 = spanId }
        return spanId
    }

    // MARK: - IdGenerator

    /// Returns the pre-reserved ID if one is available; otherwise generates a fresh random one.
    func generateSpanId() -> SpanId {
        reservedSpanId.withLock { reserved in
            if let id = reserved {
                reserved = nil
                return id
            }
            return inner.generateSpanId()
        }
    }

    func generateTraceId() -> TraceId {
        inner.generateTraceId()
    }
}
