//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension DefaultOTelSignalsHandler {

    /// Adds a Breadcrumb span event to the current Embrace session.
    /// - Parameters:
    ///   - message: Message of the breadcrumb.
    ///   - timestamp: Timestamp of the breadcrumb.
    ///   - attributes: Attributes of the breadcrumb.
    /// - Throws: `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    public func addBreadcrumb(
        _ message: String,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) throws {

        guard let span = sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession
        }

        try span.addSessionEvent(
            name: SpanEventSemantics.Breadcrumb.name,
            type: .breadcrumb,
            timestamp: timestamp,
            attributes: attributes,
            internalAttributes: [
                SpanEventSemantics.Breadcrumb.keyMessage: message
            ],
            isInternal: false
        )
    }
}
