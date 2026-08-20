//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension EmbraceAttributeValue {
    var otelAttributeValue: AttributeValue {
        switch self {
        case let s as String: return .string(s)
        case let b as Bool: return .bool(b)
        case let i as Int: return .int(i)
        case let d as Double: return .double(d)
        case let f as Float: return .double(Double(f))
        default: return .string(description)
        }
    }
}

extension EmbraceAttributes {
    var otelAttributes: [String: AttributeValue] {
        mapValues { $0.otelAttributeValue }
    }
}

extension EmbraceSpanStatus {
    var otelStatus: Status {
        switch self {
        case .ok: return .ok
        case .error: return .error(description: "")
        case .unset: return .unset
        }
    }
}
