//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

extension Span {

    func setAttribute(key: SpanAttributeKey, value: String) {
        setAttribute(key: key.rawValue, value: value)
    }

    /// Mark this Span as important  so the backend will create aggregate metrics for it, and the UI will show it as a "top level" span
    public func markAsKeySpan() {
        setAttribute(key: SpanAttributeKey.isKey, value: "true")
    }

    /// Mark this Span as private. This is used for observability of the SDK itself
    /// When marked as private, a span will not appear in the Embrace dashboard
    public func markAsPrivate() {
        setAttribute(key: SpanAttributeKey.isPrivate, value: "true")
    }

    public func end(errorCode: SpanErrorCode? = nil, time: Date = Date()) {
        if let errorCode = errorCode {
            setAttribute(key: SpanAttributeKey.errorCode, value: errorCode.rawValue)
            status = .error(description: errorCode.rawValue)
        } else {
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
