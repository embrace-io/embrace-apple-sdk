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
    public var embType: SpanType {
        if let raw = attributes[SpanSemantics.keyEmbraceType] {
            switch raw {
            case .string(let val):
                return SpanType(rawValue: val) ?? .performance
            default:
                break
            }
        }
        return .performance
    }

    var errorCode: SpanErrorCode? {
        guard let value = attributes[SpanSemantics.keyErrorCode] else {
            return nil
        }
        return SpanErrorCode(rawValue: value.description)
    }

    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
