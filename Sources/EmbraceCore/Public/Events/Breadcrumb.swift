//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal
import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi

/// Class used to represent a Breadcrum as a SpanEvent.
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
        self.name = SpanEventSemantics.Bradcrumb.name
        self.timestamp = timestamp
        self.attributes = attributes
        self.attributes[SpanEventSemantics.Bradcrumb.keyMessage] = .string(message)
        self.attributes[SpanEventSemantics.keyEmbraceType] = .string(SpanType.breadcrumb.rawValue)
    }
}

public extension SpanEvent where Self == Breadcrumb {
    static func breadcrumb(
        _ message: String,
        properties: [String: String] = [:]
    ) -> SpanEvent {
        let otelAttributes = properties.reduce(into: [String: AttributeValue]()) {
            $0[$1.key] = AttributeValue.string($1.value)
        }
        return Breadcrumb(message: message, attributes: otelAttributes)
    }
}
