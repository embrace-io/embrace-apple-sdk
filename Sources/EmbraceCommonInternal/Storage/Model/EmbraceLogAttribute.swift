//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

public enum EmbraceLogAttributeType: Int {
    case string, int, double, bool
}

public protocol EmbraceLogAttribute {
    var key: String { get }
    var valueRaw: String { get }
    var typeRaw: Int { get }
}

extension EmbraceLogAttribute {

    public var value: AttributeValue {
        let type = EmbraceLogAttributeType(rawValue: typeRaw) ?? .string

        switch type {
        case .int: return AttributeValue(Int(valueRaw) ?? 0)
        case .double: return AttributeValue(Double(valueRaw) ?? 0)
        case .bool: return AttributeValue(Bool(valueRaw) ?? false)
        default: return AttributeValue(valueRaw)
        }
    }
}
