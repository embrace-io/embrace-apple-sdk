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
extension UInt: EmbraceAttributeValue {}
extension Float: EmbraceAttributeValue {}
extension Double: EmbraceAttributeValue {}
