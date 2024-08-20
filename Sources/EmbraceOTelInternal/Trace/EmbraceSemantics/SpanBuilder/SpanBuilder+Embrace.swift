//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi

extension SpanBuilder {
    @discardableResult func setAttribute(key: String, value: String) -> Self {
        setAttribute(key: key, value: value)
        return self
    }

    @discardableResult public func markAsPrivate() -> Self {
        setAttribute(key: SpanSemantics.keyIsPrivateSpan, value: "true")
    }

    @discardableResult public func markAsKeySpan() -> Self {
        setAttribute(key: SpanSemantics.keyIsKeySpan, value: "true")
    }

    @discardableResult public func error(errorCode: ErrorCode) -> Self {
        setAttribute(key: SpanSemantics.keyErrorCode, value: errorCode.rawValue)
    }

}
