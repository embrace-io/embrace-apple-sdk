//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Key

extension EmbraceIO {

    @frozen
    public struct AttributeKey {
        public let name: String

        public init(_ name: String) {
            self.name = name
        }
    }
}

extension EmbraceIO.AttributeKey: Hashable {}
extension EmbraceIO.AttributeKey: Equatable {}
extension EmbraceIO.AttributeKey: Codable {}

extension EmbraceIO.AttributeKey: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self.name = value
    }
}

extension EmbraceIO.AttributeKey: CustomStringConvertible {

    public var description: String { name }
}

// MARK: - Value

extension EmbraceIO {

    @frozen
    public enum AttributeValue: Equatable, Hashable {
        case bool(Bool)
        case int(Int64)
        case double(Double)
        case string(String)
    }
}

extension EmbraceIO.AttributeValue: Codable {

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int64.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported scalar type for AttributeValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        }
    }
}

extension EmbraceIO.AttributeValue: CustomStringConvertible {

    public var description: String {
        switch self {
        case .bool(let b):
            return String(b)
        case .int(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .string(let s):
            return s
        }
    }
}

// MARK: - Literals

extension EmbraceIO.AttributeValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

extension EmbraceIO.AttributeValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(Int64(value))
    }
}

extension EmbraceIO.AttributeValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}

extension EmbraceIO.AttributeValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

// MARK: - Helpers

extension Dictionary where Key == EmbraceIO.AttributeKey, Value == EmbraceIO.AttributeValue {

    package func asInternalAttributes() -> [String: String] {
        [String: String](
            uniqueKeysWithValues: self.map { (key, value) in
                (key.name, "\(value.description)")
            }
        )
    }
}
