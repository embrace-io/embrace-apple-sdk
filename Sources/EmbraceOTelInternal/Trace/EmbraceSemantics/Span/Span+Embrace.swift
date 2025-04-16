//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceSemantics
#endif
import OpenTelemetryApi

extension Span {

    @available(*, deprecated, message: "The concept of key spans is no longer supported")
    public func markAsKeySpan() {
        // TODO: Remove in next major version
    }

    /// Mark this Span as private. This is used for observability of the SDK itself
    /// When marked as private, a span will not appear in the Embrace dashboard.
    /// - Note: This method should not be called by application developers, it is only public
    ///         to allow access to multiple targets within the Embrace SDK.
    public func markAsPrivate() {
        setAttribute(key: SpanSemantics.keyIsPrivateSpan, value: "true")
    }

    public func end(errorCode: SpanErrorCode? = nil, time: Date = Date()) {
        end(error: nil, errorCode: errorCode, time: time)
    }

    public func end(error: Error?, errorCode: SpanErrorCode? = nil, time: Date = Date()) {
        var errorCode = errorCode

        // get attributes from error
        if let error = error as? NSError {
            setAttribute(key: SpanSemantics.keyNSErrorMessage, value: error.localizedDescription)
            setAttribute(key: SpanSemantics.keyNSErrorCode, value: error.code)

            errorCode = errorCode ?? .failure
        }

        // set error code
        if let errorCode = errorCode {
            setAttribute(key: SpanSemantics.keyErrorCode, value: errorCode.rawValue)
            status = .error(description: errorCode.rawValue)
        } else {
            // no error or error code means the span ended successfully
            status = .ok
        }

        end(time: time)
    }
}

extension Span {
    public func add(events: [SpanEvent]) {
        events.forEach { event in
            addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
        }
    }
}
