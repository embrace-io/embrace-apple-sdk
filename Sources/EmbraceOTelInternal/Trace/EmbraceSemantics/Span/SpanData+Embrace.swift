//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetrySdk

extension SpanData {
    public var embType: SpanType {
        if let raw = attributes[SpanAttributeKey.type.rawValue] {
            switch raw {
            case let .string(val):
                return SpanType(rawValue: val) ?? .performance
            default:
                break
            }
        }
        return .performance
    }

    var errorCode: SpanErrorCode? {
        guard let value = attributes[SpanAttributeKey.errorCode.rawValue] else {
            return nil
        }
        return SpanErrorCode(rawValue: value.description)
    }

    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
