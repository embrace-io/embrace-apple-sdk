//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal

public extension W3C {
    static let traceparentHeaderName = "traceparent"

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// - Parameters:
    ///     - span: The span to create the traceparent header from
    static func traceparent(from span: Span) -> String {
        return traceparent(from: span.context)
    }

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// - Parameters:
    ///    - context:   The span context to create the traceparent header from
    static func traceparent(from context: SpanContext) -> String {
        return traceparent(
            traceId: context.traceId.hexString,
            spanId: context.spanId.hexString,
            sampled: context.traceFlags.sampled
        )
    }

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// Will generate a version `00` traceparent.
    ///  - Parameters:
    ///     - traceId: The Span's traceId
    ///     - spanId: The Span's spanId
    ///     - sampled: Whether the trace is sampled
    static func traceparent(traceId: String, spanId: String, sampled: Bool = false) -> String {
        return [
            "00",
            traceId,
            spanId,
            sampled ? "01" : "00"
        ].joined(separator: "-")
    }

}
