//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension DefaultOTelSignalsHandler {

    /// Adds a Breadcrumb span event to the current Embrace session.
    /// If no session is active or the event limit has been reached, the breadcrumb is dropped and a warning is logged.
    /// - Parameters:
    ///   - message: Message of the breadcrumb.
    ///   - timestamp: Timestamp of the breadcrumb.
    ///   - attributes: Attributes of the breadcrumb.
    package func addBreadcrumb(
        _ message: String,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) {

        guard let span = sessionController?.currentSessionSpan else {
            Embrace.logger.warning("Failed to add breadcrumb: \(EmbraceOTelError.invalidSession.localizedDescription)")
            return
        }

        do {
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
        } catch {
            Embrace.logger.warning("Failed to add breadcrumb: \(error.localizedDescription)")
        }
    }
}
