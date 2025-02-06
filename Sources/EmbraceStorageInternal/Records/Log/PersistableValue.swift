//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum PersistableValue: Equatable, CustomStringConvertible, Hashable, Codable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case stringArray([String])
    case boolArray([Bool])
    case intArray([Int])
    case doubleArray([Double])

    public var description: String {
        switch self {
        case let .string(value):
            return value
        case let .bool(value):
            return value ? "true" : "false"
        case let .int(value):
            return String(value)
        case let .double(value):
            return String(value)
        case let .stringArray(value):
            return value.description
        case let .boolArray(value):
            return value.description
        case let .intArray(value):
            return value.description
        case let .doubleArray(value):
            return value.description
        }
    }

    public init?(_ value: Any) {
        switch value {
        case let val as String:
            self = .string(val)
        case let val as Bool:
            self = .bool(val)
        case let val as Int:
            self = .int(val)
        case let val as Double:
            self = .double(val)
        case let val as [String]:
            self = .stringArray(val)
        case let val as [Bool]:
            self = .boolArray(val)
        case let val as [Int]:
            self = .intArray(val)
        case let val as [Double]:
            self = .doubleArray(val)
        default:
            return nil
        }
    }
}

public extension PersistableValue {
    init(_ value: String) {
        self = .string(value)
    }

    init(_ value: Bool) {
        self = .bool(value)
    }

    init(_ value: Int) {
        self = .int(value)
    }

    init(_ value: Double) {
        self = .double(value)
    }

    init(_ value: [String]) {
        self = .stringArray(value)
    }

    init(_ value: [Int]) {
        self = .intArray(value)
    }

    init(_ value: [Double]) {
        self = .doubleArray(value)
    }
}
