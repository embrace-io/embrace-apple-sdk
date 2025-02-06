//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

public enum EmbraceLogAttributeType: Int {
    case string, int, double, bool
}

public protocol EmbraceLogAttribute {
    var key: String { get set }
    var valueRaw: String { get set }
    var typeRaw: Int { get set }
}

public extension EmbraceLogAttribute {

    var value: AttributeValue {
        get {
            let type = EmbraceLogAttributeType(rawValue: typeRaw) ?? .string

            switch  type {
            case .int: return AttributeValue(Int(valueRaw) ?? 0)
            case .double: return AttributeValue(Double(valueRaw) ?? 0)
            case .bool: return AttributeValue(Bool(valueRaw) ?? false)
            default: return AttributeValue(valueRaw)
            }
        }

        set {
            valueRaw = newValue.description
            typeRaw = typeForValue(newValue).rawValue
        }
    }

    func typeForValue(_ value: AttributeValue) -> EmbraceLogAttributeType {
        switch value {
        case .int: return .int
        case .double: return .double
        case .bool: return .bool
        default: return .string
        }
    }
}
