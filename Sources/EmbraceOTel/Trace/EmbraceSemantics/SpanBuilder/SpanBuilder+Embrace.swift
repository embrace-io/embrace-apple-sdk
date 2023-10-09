//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import OpenTelemetryApi

extension SpanBuilder {
    func setAttribute(key: SpanAttributeKey, value: String) -> Self {
        setAttribute(key: key.rawValue, value: value)
        return self
    }
}
