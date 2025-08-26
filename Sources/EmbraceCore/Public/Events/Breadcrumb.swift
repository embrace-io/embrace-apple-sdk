//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Class used to represent a Breadcrumb as a `EmbraceSpanEvent`.
/// Usage example:
/// `Embrace.client?.otel.addSessionEvent(.breadcrumb("This is a breadcrumb"))`
@objc(EMBBreadcrumb)
public class Breadcrumb: EmbraceSpanEvent {
    init(
        message: String,
        timestamp: Date = Date(),
        attributes: [String: String] = [:]
    ) {
        var finalAttributes = attributes
        finalAttributes[SpanEventSemantics.Breadcrumb.keyMessage] = message

        super.init(
            name: SpanEventSemantics.Breadcrumb.name,
            type: .breadcrumb,
            timestamp: timestamp,
            attributes: finalAttributes
        )
    }
}

extension EmbraceSpanEvent {
    public static func breadcrumb(
        _ message: String,
        attributes: [String: String] = [:]
    ) -> EmbraceSpanEvent {
        return Breadcrumb(message: message, attributes: attributes)
    }
}

extension EmbraceSpanEvent {
    var isBreadcrumb: Bool {
        return type == .breadcrumb
    }
}
