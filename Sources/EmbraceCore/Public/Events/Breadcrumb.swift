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

/// A lightweight breadcrumb event.
///
/// Breadcrumbs are quick, message-only events with a timestamp. Use them to understand the sequence
/// of actions leading up to issues or crashes. For additional metadata, prefer Logs or SpanEvents.
///
/// Usage:
/// ```swift
/// Embrace.client?.add(event: .breadcrumb("User tapped login"))
/// ```
@objc(EMBBreadcrumb)
public class Breadcrumb: NSObject, SpanEvent {
    public let name: String
    public let timestamp: Date

    /// The message describing this breadcrumb event.
    public let message: String

    /// Creates a message-only breadcrumb.
    /// - Parameters:
    ///   - message: The breadcrumb message.
    ///   - timestamp: When the breadcrumb occurred (defaults to now).
    init(
        message: String,
        timestamp: Date = Date()
    ) {
        self.name = SpanEventSemantics.Breadcrumb.name
        self.timestamp = timestamp
        self.message = message
    }

    /// Creates a breadcrumb. Attributes are ignored.
    /// - Parameters:
    ///   - message: The breadcrumb message.
    ///   - timestamp: When the breadcrumb occurred.
    ///   - attributes: Deprecated and ignored. Use a Log or SpanEvent if you need metadata.
    @available(*, deprecated, message: "Attributes are not supported on breadcrumbs. Use a Log or SpanEvent instead if you require attribute support.")
    convenience init(
        message: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue]
    ) {
        if !attributes.isEmpty {
            Embrace.logger.warning("Breadcrumb attributes are not supported and will be dropped. Use a Log or SpanEvent instead.")
        }
        self.init(message: message, timestamp: timestamp)
    }

    /// Attributes for OpenTelemetry compatibility (deprecated).
    /// Returns only the message and type. Use Logs or SpanEvents for custom metadata.
    @available(*, deprecated, message: "Attributes are not supported on breadcrumbs. Use a Log or SpanEvent instead if you require attribute support.")
    public var attributes: [String: AttributeValue] {
        [
            SpanEventSemantics.Breadcrumb.keyMessage: .string(message),
            SpanEventSemantics.keyEmbraceType: .string(SpanEventType.breadcrumb.rawValue)
        ]
    }
}

extension SpanEvent where Self == Breadcrumb {

    /// Creates a breadcrumb with the given message.
    /// - Parameter message: A descriptive message.
    /// - Returns: A breadcrumb event.
    public static func breadcrumb(
        _ message: String
    ) -> SpanEvent {
        Breadcrumb(message: message)
    }

    /// Creates a breadcrumb. Properties are deprecated and ignored.
    /// - Parameters:
    ///   - message: A descriptive message.
    ///   - properties: Deprecated. Use Logs or SpanEvents for custom attributes.
    /// - Returns: A breadcrumb event.
    @available(*, deprecated, message: "Attributes are not supported on breadcrumbs. Use a Log or SpanEvent instead if you require attribute support.")
    public static func breadcrumb(
        _ message: String,
        properties: [String: String] = [:]
    ) -> SpanEvent {
        if !properties.isEmpty {
            Embrace.logger.warning("Breadcrumb properties are not supported and will be dropped. Use a Log or SpanEvent instead.")
        }
        return breadcrumb(message)
    }
}

extension SpanEvent {
    var isBreadcrumb: Bool {
        name == SpanEventSemantics.Breadcrumb.name
    }
}
