//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension Dictionary where Key == String, Value == AttributeValue {
    func toEmbraceAttributes() -> EmbraceAttributes {
        var result = EmbraceAttributes()
        for (key, value) in self {
            switch value {
            case .string(let v): result[key] = v
            case .bool(let v): result[key] = v
            case .int(let v): result[key] = v
            case .double(let v): result[key] = v
            default:
                // Arrays and other composite types are not representable
                // as EmbraceAttributeValue primitives; skip them.
                break
            }
        }
        return result
    }
}
