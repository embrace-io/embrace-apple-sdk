//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents the context for a `EmbraceSpan`.
public class EmbraceSpanContext {

    /// Span identifier
    public let spanId: String

    /// Trace identifier
    public let traceId: String

    /// Creates a new `EmbraceSpanContext`.
    /// - Parameters:
    ///   - spanId: Span identifier of the context
    ///   - traceId: Trace identifier of the context
    public init(spanId: String, traceId: String) {
        self.spanId = spanId
        self.traceId = traceId
    }
}

// MARK: Validation
extension EmbraceSpanContext {

    /// Amount of hexadecimal characters in a well formed trace identifier.
    public static let traceIdLength = 32

    /// Amount of hexadecimal characters in a well formed span identifier.
    public static let spanIdLength = 16

    /// Returns wether the given string can be used as a trace identifier.
    /// A valid trace identifier is exactly 32 hexadecimal characters and is not entirely made of zeros.
    /// - Parameter traceId: The string to validate.
    public static func isValidTraceId(_ traceId: String) -> Bool {
        return isValidIdentifier(traceId, length: traceIdLength)
    }

    /// Returns wether the given string can be used as a span identifier.
    /// A valid span identifier is exactly 16 hexadecimal characters and is not entirely made of zeros.
    /// - Parameter spanId: The string to validate.
    public static func isValidSpanId(_ spanId: String) -> Bool {
        return isValidIdentifier(spanId, length: spanIdLength)
    }

    /// Returns wether both identifiers in this context are well formed.
    public var isValid: Bool {
        return Self.isValidSpanId(spanId) && Self.isValidTraceId(traceId)
    }

    /// Identifiers are compared and stored in lowercase, so the same value written in either
    /// case always ends up as the same identifier.
    /// - Parameter identifier: The identifier to normalize.
    public static func normalize(_ identifier: String) -> String {
        return identifier.lowercased()
    }

    private static func isValidIdentifier(_ value: String, length: Int) -> Bool {
        guard value.count == length else {
            return false
        }

        var isAllZeros = true

        for character in value {
            // The ASCII check matters: `isHexDigit` also accepts fullwidth variants, which can't
            // be parsed back into an identifier by anything consuming these strings downstream.
            guard character.isASCII, character.isHexDigit else {
                return false
            }

            if character != "0" {
                isAllZeros = false
            }
        }

        return !isAllZeros
    }
}
