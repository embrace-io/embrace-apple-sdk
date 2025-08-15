//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension SpanBuilder {
    @discardableResult func setAttribute(key: String, value: String) -> Self {
        setAttribute(key: key, value: value)
        return self
    }

    @discardableResult public func markAsPrivate() -> Self {
        setAttribute(key: SpanSemantics.keyIsPrivateSpan, value: "true")
    }

    @available(*, deprecated, message: "The concept of key spans is no longer supported")
    @discardableResult public func markAsKeySpan() -> Self {
        // TODO: Remove in next major version
        return self
    }

    @discardableResult public func error(errorCode: EmbraceSpanErrorCode) -> Self {
        setAttribute(key: SpanSemantics.keyErrorCode, value: errorCode.rawValue)
    }

}
