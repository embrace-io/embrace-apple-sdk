//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceOTelInternal
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Class used to represent a Breadcrumb as a SpanEvent.
/// Usage example:
/// `Embrace.client?.add(.breadcrumb("This is a breadcrumb"))`
@objc(EMBBreadcrumb)
public class Breadcrumb: NSObject, SpanEvent {
    public let name: String
    public let timestamp: Date
    public let message: String

    init(
        message: String,
        timestamp: Date = Date(),
    ) {
        self.name = SpanEventSemantics.Breadcrumb.name
        self.timestamp = timestamp
        self.message = message
    }

    @available(*, deprecated, message: "Attributes are not supported on breadcrumbs. Use a Log or SpanEvent instead if you require attribute support.")
    convenience init(
        message: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue]
    ) {
        self.init(message: message, timestamp: timestamp)
    }

    @available(*, deprecated, message: "Attributes are not supported on breadcrumbs. Use a Log or SpanEvent instead if you require attribute support.")
    public var attributes: [String: AttributeValue] {
        [
            SpanEventSemantics.Breadcrumb.keyMessage: .string(message),
            SpanEventSemantics.keyEmbraceType: .string(SpanEventType.breadcrumb.rawValue)
        ]
    }
}

extension SpanEvent where Self == Breadcrumb {

    public static func breadcrumb(
        _ message: String
    ) -> SpanEvent {
        Breadcrumb(message: message)
    }

    @available(*, deprecated, message: "Attributes are not supported on breadcrumbs. Use a Log or SpanEvent instead if you require attribute support.")
    public static func breadcrumb(
        _ message: String,
        properties: [String: String] = [:]
    ) -> SpanEvent {
        breadcrumb(message)
    }
}

extension SpanEvent {
    var isBreadcrumb: Bool {
        attributes[SpanEventSemantics.keyEmbraceType] == .string(SpanEventType.breadcrumb.rawValue)
    }
}
