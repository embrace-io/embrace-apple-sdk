//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

@objc public extension EmbraceOTelSignalsHandler {
    
    /// Adds a Breadcrumb span event to the current Embrace session.
    /// - Parameters:
    ///   - message: Message of the breadcrumb.
    ///   - timestamp: Timestamp of the breadcrumb.
    ///   - attributes: Attributes of the breadcrumb.
    /// - Throws: `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    @objc func addBreadcrumb(
        _ message: String,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
    ) throws {

        guard let span = sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession
        }

        guard limiter.shouldAddSessionEvent(ofType: .breadcrumb) else {
            throw EmbraceOTelError.spanEventLimitReached("Breadcrumb limit reached for the span event type!")
        }

        var finalAttributes = sanitizer.sanitizeSpanEventAttributes(attributes)
        finalAttributes[SpanEventSemantics.Breadcrumb.keyMessage] = message

        let event = EmbraceSpanEvent(
            name: SpanEventSemantics.Breadcrumb.name,
            type: .breadcrumb,
            timestamp: timestamp,
            attributes: finalAttributes
        )

        span.addSessionEvent(event)
    }
}
