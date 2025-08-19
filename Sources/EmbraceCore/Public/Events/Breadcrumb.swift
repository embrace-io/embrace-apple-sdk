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
    public private(set) var attributes: [String: AttributeValue]

    init(
        message: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue]
    ) {
        self.name = SpanEventSemantics.Breadcrumb.name
        self.timestamp = timestamp
        self.attributes = attributes
        self.attributes[SpanEventSemantics.Breadcrumb.keyMessage] = .string(message)
        self.attributes[SpanEventSemantics.keyEmbraceType] = .string(EmbraceType.breadcrumb.rawValue)
    }
}

extension SpanEvent where Self == Breadcrumb {
    public static func breadcrumb(
        _ message: String,
        properties: [String: String] = [:]
    ) -> SpanEvent {
        let otelAttributes = properties.reduce(into: [String: AttributeValue]()) {
            $0[$1.key] = AttributeValue.string($1.value)
        }
        return Breadcrumb(message: message, attributes: otelAttributes)
    }
}

extension SpanEvent {
    var isBreadcrumb: Bool {
        attributes[SpanEventSemantics.keyEmbraceType] == .string(EmbraceType.breadcrumb.rawValue)
    }
}
