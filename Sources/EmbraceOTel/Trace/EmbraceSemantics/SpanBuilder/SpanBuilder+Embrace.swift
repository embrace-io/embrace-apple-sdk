//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon
import OpenTelemetryApi

extension SpanBuilder {
    @discardableResult func setAttribute(key: SpanAttributeKey, value: String) -> Self {
        setAttribute(key: key.rawValue, value: value)
        return self
    }

    @discardableResult public func markAsPrivate() -> Self {
        setAttribute(key: .isPrivate, value: "true")
    }

    @discardableResult public func markAsKeySpan() -> Self {
        setAttribute(key: .isKey, value: "true")
    }

    @discardableResult public func error(errorCode: SpanErrorCode) -> Self {
        setAttribute(key: SpanAttributeKey.errorCode, value: errorCode.rawValue)
    }

}
