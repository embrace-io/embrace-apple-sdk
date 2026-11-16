//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

extension Optional where Wrapped == AttributeValue {
    /// Whether an `emb.type` attribute value has to be replaced by the default type.
    /// Missing values and empty strings are treated as not present.
    var isMissingEmbraceType: Bool {
        switch self {
        case .none:
            return true
        case .some(.string(let value)):
            return value.isEmpty
        case .some:
            return false
        }
    }
}
