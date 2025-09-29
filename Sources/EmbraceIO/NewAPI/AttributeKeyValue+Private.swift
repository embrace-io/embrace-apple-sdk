//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

private let _attributeValueTypeSupportedTypes: [Any.Type] = [
    String.self, Bool.self,
    Int.self, Int16.self, Int32.self, Int64.self,
    UInt.self, UInt8.self, UInt16.self, UInt32.self, UInt64.self,
    Float.self, Float64.self,
    Double.self
]

internal func isSupportedAttributeValueType<T>(_ value: T) -> Bool {
    _attributeValueTypeSupportedTypes.contains { $0 == type(of: T.self) }
}

// CustomStringConvertible
extension EmbraceIO.AttributeValueType {

    public var description: String {
        assert(
            isSupportedAttributeValueType(self),
            "Unsupported type '\(type(of: self))'"
        )
        return "\(self)"
    }
}

// MARK: - Helpers

extension Dictionary where Key == EmbraceIO.AttributeKey, Value == EmbraceIO.AttributeValueType {

    package func asInternalAttributes() -> [String: String] {
        [String: String](
            uniqueKeysWithValues: self.map { (key, value) in
                (key.name, value.description)
            }
        )
    }
}
