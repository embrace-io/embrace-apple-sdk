//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

extension Span {

    func setAttribute(key: SpanAttributeKey, value: String) {
        setAttribute(key: key.rawValue, value: value)
    }

    /// Mark this Span as important  so the backend will create aggregate metrics for it, and the UI will prioritize this span
    public func markAsKeySpan() {
        setAttribute(key: SpanAttributeKey.isKey, value: "true")
    }

    /// Mark this Span as private. This is used for observability of the SDK itself
    /// When marked as private, a span will not appear in the Embrace dashboard.
    /// - Note: This method should not be called by application developers, it is only public
    ///         to allow access to multiple targets within the Embrace SDK.
    public func markAsPrivate() {
        setAttribute(key: SpanAttributeKey.isPrivate, value: "true")
    }

    public func end(errorCode: SpanErrorCode? = nil, time: Date = Date()) {
        end(error: nil, errorCode: errorCode, time: time)
    }

    public func end(error: Error?, errorCode: SpanErrorCode? = nil, time: Date = Date()) {
        var errorCode = errorCode

        // get attributes from error
        if let error = error as? NSError {
            setAttribute(key: SpanErrorAttributeKey.message.rawValue, value: error.localizedDescription)
            setAttribute(key: SpanErrorAttributeKey.code.rawValue, value: error.code)

            errorCode = errorCode ?? .failure
        }

        // set error code
        if let errorCode = errorCode {
            setAttribute(key: SpanAttributeKey.errorCode, value: errorCode.rawValue)
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
