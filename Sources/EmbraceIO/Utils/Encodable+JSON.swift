//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// swiftlint:disable cyclomatic_complexity

struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}

extension KeyedEncodingContainerProtocol where Key == JSONCodingKeys {

    mutating func encode(_ value: [String: Any]) throws {
        for (key, value) in value {
            let key = JSONCodingKeys(stringValue: key)

            // special case for booleans
            if value is Bool,
               let bval = value as? NSNumber {
                if bval === kCFBooleanTrue || bval === kCFBooleanFalse {
                    try encode(bval.boolValue, forKey: key)
                } else if value is Int {
                    try encode(bval.intValue, forKey: key)
                }
            } else {

                switch value {

                case let value as Int:
                    try encode(value, forKey: key)
                case let value as Int8:
                    try encode(value, forKey: key)
                case let value as Int16:
                    try encode(value, forKey: key)
                case let value as Int32:
                    try encode(value, forKey: key)
                case let value as Int64:
                    try encode(value, forKey: key)
                case let value as UInt:
                    try encode(value, forKey: key)
                case let value as UInt8:
                    try encode(value, forKey: key)
                case let value as UInt16:
                    try encode(value, forKey: key)
                case let value as UInt32:
                    try encode(value, forKey: key)
                case let value as UInt64:
                    try encode(value, forKey: key)
                case let value as Float:
                    try encode(value, forKey: key)
                case let value as Double:
                    try encode(value, forKey: key)
                case let value as String:
                    try encode(value, forKey: key)
                case let value as [String: Any]:
                    try encode(value, forKey: key)
                case let value as [Any]:
                    try encode(value, forKey: key)
                case is NSNull:
                    try encodeNil(forKey: key)
                case Optional<Any>.none:
                    try encodeNil(forKey: key)
                default:
                    throw EncodingError.invalidValue(
                        value,
                        EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Invalid JSON value")
                    )
                }
            }
        }
    }
}

extension KeyedEncodingContainerProtocol {
    mutating func encode(_ value: [String: Any]?, forKey key: Key) throws {
        guard let value = value else {
            return
        }

        var container = nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        try container.encode(value)
    }

    mutating func encode(_ value: [Any]?, forKey key: Key) throws {
        guard let value = value else {
            return
        }

        var container = nestedUnkeyedContainer(forKey: key)
        try container.encode(value)
    }
}

extension UnkeyedEncodingContainer {

    mutating func encode(_ value: [Any]) throws {
        for (index, value) in value.enumerated() {
            switch value {
            case let value as Bool:
                try encode(value)
            case let value as Int:
                try encode(value)
            case let value as Int8:
                try encode(value)
            case let value as Int16:
                try encode(value)
            case let value as Int32:
                try encode(value)
            case let value as Int64:
                try encode(value)
            case let value as UInt:
                try encode(value)
            case let value as UInt8:
                try encode(value)
            case let value as UInt16:
                try encode(value)
            case let value as UInt32:
                try encode(value)
            case let value as UInt64:
                try encode(value)
            case let value as Float:
                try encode(value)
            case let value as Double:
                try encode(value)
            case let value as String:
                try encode(value)
            case let value as [String: Any]:
                try encode(value)
            case let value as [Any]:
                try encodeNestedArray(value)
            case is NSNull:
                try encodeNil()
            case Optional<Any>.none:
                try encodeNil()
            default:
                let keys = JSONCodingKeys(intValue: index).map({ [ $0 ] }) ?? []
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(codingPath: codingPath + keys, debugDescription: "Invalid JSON value")
                )
            }
        }
    }

    mutating func encode(_ value: [String: Any]) throws {
        var container = nestedContainer(keyedBy: JSONCodingKeys.self)
        try container.encode(value)
    }

    mutating func encodeNestedArray(_ value: [Any]) throws {
        var container = nestedUnkeyedContainer()
        try container.encode(value)
    }
}

// swiftlint:enable cyclomatic_complexity
