//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// Attributes structure used in all OTel signals.
public typealias EmbraceAttributes = [String: EmbraceAttributeValue]

/// Attribute values support common primitive types.
public protocol EmbraceAttributeValue: CustomStringConvertible, Sendable {}

extension String: EmbraceAttributeValue {}
extension Bool: EmbraceAttributeValue {}
extension Int: EmbraceAttributeValue {}
extension Int8: EmbraceAttributeValue {}
extension Int16: EmbraceAttributeValue {}
extension Int32: EmbraceAttributeValue {}
extension Int64: EmbraceAttributeValue {}
extension UInt: EmbraceAttributeValue {}
extension UInt8: EmbraceAttributeValue {}
extension UInt16: EmbraceAttributeValue {}
extension UInt32: EmbraceAttributeValue {}
extension UInt64: EmbraceAttributeValue {}
extension Float: EmbraceAttributeValue {}
extension Double: EmbraceAttributeValue {}
