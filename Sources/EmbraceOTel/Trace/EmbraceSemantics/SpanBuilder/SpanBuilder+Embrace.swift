//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

extension SpanBuilder {

    func setAttribute(key: EmbraceSemantics.AttributeKey, value: String) -> Self {
        setAttribute(key: key.rawValue, value: value)
        return self
    }

}
