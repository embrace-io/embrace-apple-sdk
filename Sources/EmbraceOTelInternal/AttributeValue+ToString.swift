//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

extension Dictionary where Key == String, Value == AttributeValue {
    public func toStringValues() -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in self {
            switch value {
            case .boolArray, .intArray, .doubleArray, .stringArray:
                continue
            default:
                result[key] = value.description
            }
        }

        return result
    }
}
