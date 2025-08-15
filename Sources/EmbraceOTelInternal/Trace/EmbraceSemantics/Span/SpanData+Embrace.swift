//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension SpanData {
    public var embType: EmbraceType {
        if let raw = attributes[SpanSemantics.keyEmbraceType] {
            switch raw {
            case let .string(val):
                return EmbraceType(rawValue: val) ?? .performance
            default:
                break
            }
        }
        return .performance
    }

    var errorCode: EmbraceSpanErrorCode? {
        guard let value = attributes[SpanSemantics.keyErrorCode] else {
            return nil
        }
        return EmbraceSpanErrorCode(rawValue: value.description)
    }

    public var embStatus: EmbraceSpanStatus {
        switch status {
        case .ok: return .ok
        case .error: return .error
        default: return .unset
        }
    }

    public var embEvents: [EmbraceSpanEvent] {
        return events.map {
            EmbraceSpanEvent(
                name: $0.name,
                timestamp: $0.timestamp,
                attributes: $0.attributes.toStringValues()
            )
        }
    }

    public var embLinks: [EmbraceSpanLink] {
        return links.map {
            EmbraceSpanLink(
                spanId: $0.context.spanId.hexString,
                traceId: $0.context.traceId.hexString,
                attributes: $0.attributes.toStringValues()
            )
        }
    }

    public var embAttributes: [String: String] {
        attributes.toStringValues()
    }

    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
