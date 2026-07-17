//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Breadcrumbs
extension EmbraceIO {

    /// Adds a Breadcrumb span event to the current Embrace session.
    /// If no session is active or the event limit has been reached, the breadcrumb is dropped and a warning is logged.
    /// - Parameters:
    ///   - message: Message of the breadcrumb.
    ///   - timestamp: Timestamp of the breadcrumb.
    ///   - attributes: Attributes of the breadcrumb.
    public func addBreadcrumb(
        _ message: String,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) {
        Embrace.client?.otel.addBreadcrumb(
            message,
            timestamp: timestamp,
            attributes: attributes
        )
    }
}
