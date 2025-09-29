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

    public protocol AttributeValueType: CustomStringConvertible, Sendable {}
}

extension String: EmbraceIO.AttributeValueType {}
extension Bool: EmbraceIO.AttributeValueType {}

extension Int: EmbraceIO.AttributeValueType {}
extension Int8: EmbraceIO.AttributeValueType {}
extension Int16: EmbraceIO.AttributeValueType {}
extension Int32: EmbraceIO.AttributeValueType {}
extension Int64: EmbraceIO.AttributeValueType {}

extension UInt: EmbraceIO.AttributeValueType {}
extension UInt8: EmbraceIO.AttributeValueType {}
extension UInt16: EmbraceIO.AttributeValueType {}
extension UInt32: EmbraceIO.AttributeValueType {}
extension UInt64: EmbraceIO.AttributeValueType {}

extension Float: EmbraceIO.AttributeValueType {}
extension Float64: EmbraceIO.AttributeValueType {}
