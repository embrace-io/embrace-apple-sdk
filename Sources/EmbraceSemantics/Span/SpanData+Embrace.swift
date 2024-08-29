//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetrySdk

extension SpanData {
    public var embType: SpanType {
        if let raw = attributes[SpanSemantics.keyEmbraceType] {
            switch raw {
            case let .string(val):
                return SpanType(rawValue: val) ?? .performance
            default:
                break
            }
        }
        return .performance
    }

    public var errorCode: ErrorCode? {
        guard let value = attributes[SpanSemantics.keyErrorCode] else {
            return nil
        }
        return ErrorCode(rawValue: value.description)
    }

    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
