//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

package struct W3C {
    private init() {}

    package static let traceparentHeaderName = "traceparent"

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// - Parameters:
    ///     - span: The span to create the traceparent header from
    package static func traceparent(from span: EmbraceSpan) -> String {
        return traceparent(from: span.context)
    }

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// - Parameters:
    ///    - context:   The span context to create the traceparent header from
    package static func traceparent(from context: EmbraceSpanContext) -> String {
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
    package static func traceparent(traceId: String, spanId: String, sampled: Bool = true) -> String {
        return traceparent(traceId: traceId, spanId: spanId, flags: sampled ? "01" : "00")
    }

    /// Creates a W3C [traceparent](https://www.w3.org/TR/trace-context/#traceparent-header) header value.
    /// Will generate a version `00` traceparent.
    ///  - Parameters:
    ///     - traceId: The Span's traceId
    ///     - spanId: The Span's spanId
    ///     - flags: The trace-flags byte as two hexadecimal characters, written as given.
    package static func traceparent(traceId: String, spanId: String, flags: String) -> String {
        return [
            "00",
            traceId,
            spanId,
            flags
        ].joined(separator: "-")
    }
}

// MARK: Parsing
extension W3C {

    /// The fields of a well-formed `traceparent` header value.
    package struct ParsedTraceparent: Equatable {
        /// Trace identifier, 32 lowercase hexadecimal characters.
        package let traceId: String

        /// Identifier of the span that made the request, 16 lowercase hexadecimal characters.
        package let spanId: String

        /// Trace-flags byte as two lowercase hexadecimal characters, exactly as received.
        package let flags: String

        /// The span the header names, as a span context.
        package var context: EmbraceSpanContext {
            EmbraceSpanContext(spanId: spanId, traceId: traceId)
        }
    }

    /// Parses a `traceparent` header value.
    ///
    /// A value is well formed when:
    /// - Its version is two lowercase hexadecimal characters other than `ff`.
    /// - For version `00`, it has exactly four `-` separated fields.
    /// - For later versions, it has at least four fields. Anything after the fourth one is ignored.
    /// - Its trace id is 32 lowercase hexadecimal characters, its span id 16, and its flags 2.
    /// - Neither its trace id nor its span id is entirely made of zeros.
    ///
    /// A request that carries more than one `traceparent` header is reported by `URLRequest` as a
    /// single comma-joined value, which never passes these rules.
    ///
    /// - Parameter value: The header value.
    /// - Returns: The parsed fields, or `nil` when the value is missing or not well formed.
    package static func parseTraceparent(_ value: String?) -> ParsedTraceparent? {
        guard let value else {
            return nil
        }

        let fields = value.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count >= 4 else {
            return nil
        }

        let version = fields[0]
        guard isLowercaseHex(version, length: 2), version != "ff" else {
            return nil
        }

        if version == "00" && fields.count != 4 {
            return nil
        }

        let traceId = fields[1]
        let spanId = fields[2]
        let flags = fields[3]

        guard isLowercaseHex(traceId, length: EmbraceSpanContext.traceIdLength),
            isLowercaseHex(spanId, length: EmbraceSpanContext.spanIdLength),
            isLowercaseHex(flags, length: 2),
            !isAllZeros(traceId),
            !isAllZeros(spanId)
        else {
            return nil
        }

        return ParsedTraceparent(traceId: String(traceId), spanId: String(spanId), flags: String(flags))
    }

    private static func isLowercaseHex(_ value: Substring, length: Int) -> Bool {
        guard value.utf8.count == length else {
            return false
        }

        // Checked on the raw bytes: `Character.isHexDigit` also accepts uppercase and fullwidth digits,
        // which the header grammar doesn't allow.
        return value.utf8.allSatisfy { byte in
            (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")) || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "f"))
        }
    }

    private static func isAllZeros(_ value: Substring) -> Bool {
        return value.utf8.allSatisfy { $0 == UInt8(ascii: "0") }
    }
}
