//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import OpenTelemetrySdk

extension SpanData {
    var embType: EmbraceSemantics.SpanType {
        if let raw = attributes[EmbraceSemantics.AttributeKey.type.rawValue] {
            switch raw {
            case let .string(val):
                return EmbraceSemantics.SpanType(rawValue: val) ?? .performance
            default:
                break
            }
        }
        return .performance
    }

    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
