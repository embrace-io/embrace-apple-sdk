//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension W3C {
    public static let traceparentHeaderName = "traceparent"

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// - Parameters:
    ///     - span: The span to create the traceparent header from
    public static func traceparent(from span: EmbraceSpan) -> String {
        return traceparent(from: span.context)
    }

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// - Parameters:
    ///    - context:   The span context to create the traceparent header from
    public static func traceparent(from context: EmbraceSpanContext) -> String {
        return traceparent(
            traceId: context.traceId,
            spanId: context.spanId
        )
    }

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// Will generate a version `00` traceparent.
    ///  - Parameters:
    ///     - traceId: The Span's traceId
    ///     - spanId: The Span's spanId
    ///     - sampled: Whether the trace is sampled
    public static func traceparent(traceId: String, spanId: String, sampled: Bool = false) -> String {
        return [
            "00",
            traceId,
            spanId,
            sampled ? "01" : "00"
        ].joined(separator: "-")
    }

}
