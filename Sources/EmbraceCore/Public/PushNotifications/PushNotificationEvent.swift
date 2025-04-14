//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import UserNotifications
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceOTelInternal
import EmbraceCommonInternal
import EmbraceSemantics
#endif
import OpenTelemetryApi

/// Class used to represent a Push Notification as a SpanEvent.
/// Usage example:
/// `Embrace.client?.add(.push(userInfo: apsDictionary))`
@objc(EMBPushNotificationEvent)
public class PushNotificationEvent: NSObject, SpanEvent {
    public let name: String
    public let timestamp: Date
    public private(set) var attributes: [String: AttributeValue]

    /// Returns a span event on using the data from the given `UNNotification`
    /// - Parameters:
    ///   - notification: The `UNNotification` received by the app
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification
    /// - Throws: `PushNotificationError.invalidPayload` if the `aps` object is not present in the `userInfo` of the `UNNotification`.
    convenience init(notification: UNNotification,
                     timestamp: Date = Date(),
                     attributes: [String: AttributeValue] = [:],
                     captureData: Bool = true
    ) throws {
        var userInfo: [AnyHashable: Any] = [:]
#if !os(tvOS)
        userInfo = notification.request.content.userInfo
#endif
        try self.init(userInfo: userInfo, attributes: attributes, captureData: captureData)
    }

    /// Returns a span event on using the `userInfo` dictionary from a push notification
    /// - Parameters:
    ///   - userInfo: The `userInfo` dictionary from a push notification		o	or
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification
    /// - Throws: `PushNotificationError.invalidPayload` if the `aps` object is not present in the `userInfo` of the `UNNotification`.
    init(userInfo: [AnyHashable: Any],
         timestamp: Date = Date(),
         attributes: [String: AttributeValue] = [:],
         captureData: Bool = true
    ) throws {

        // find aps key
        guard let apsDict = userInfo[Constants.apsRootKey] as? [AnyHashable: Any] else {
            throw PushNotificationError.invalidPayload("Couldn't find aps object!")
        }

        self.name = SpanEventSemantics.PushNotification.name
        self.timestamp = timestamp

        let dict = Self.parse(apsDict: apsDict, captureData: captureData)
        self.attributes = attributes.merging(dict) { (current, _) in current }
    }

    static func parse(apsDict: [AnyHashable: Any], captureData: Bool) -> [String: AttributeValue] {

        var dict: [String: AttributeValue] = [:]

        // set types
        dict[SpanEventSemantics.keyEmbraceType] = .string(SpanEventType.pushNotification.rawValue)
        dict[SpanEventSemantics.PushNotification.keyType] =
            isSilent(userInfo: apsDict) ?
            .string(SpanEventSemantics.PushNotification.silentType) :
            .string(SpanEventSemantics.PushNotification.notificationType)

        // capture data if enabled
        if captureData {
            var title: String?
            var subtitle: String?
            var body: String?

            if let alertData = apsDict[Constants.apsAlert] as? [AnyHashable: Any] {
                title = alertData[Constants.apsTitle] as? String
                ?? alertData[Constants.apsTitleLocalized] as? String

                subtitle = alertData[Constants.apsSubtitle] as? String
                ?? alertData[Constants.apsSubtitleLocalized] as? String

                body = alertData[Constants.apsBody] as? String
                ?? alertData[Constants.apsBodyLocalized] as? String
            }

            let category = apsDict[Constants.apsCategory] as? String
            let badge = apsDict[Constants.apsBadge] as? Int

            if let title = title {
                dict[SpanEventSemantics.PushNotification.keyTitle] = .string(title)
            }

            if let subtitle = subtitle {
                dict[SpanEventSemantics.PushNotification.keySubtitle] = .string(subtitle)
            }

            if let body = body {
                dict[SpanEventSemantics.PushNotification.keyBody] = .string(body)
            }

            if let category = category {
                dict[SpanEventSemantics.PushNotification.keyCategory] = .string(category)
            }

            if let badge = badge {
                dict[SpanEventSemantics.PushNotification.keyBadge] = .int(badge)
            }
        }

        return dict
    }

    // MARK: - Private
    private static func isSilent(userInfo: [AnyHashable: Any]) -> Bool {
        guard let contentAvailable = userInfo[Constants.apsContentAvailable] as? Int else {
            return false
        }

        return contentAvailable == 1
    }

    struct Constants {
        static let apsRootKey = "aps"
        static let apsAlert = "alert"
        static let apsTitle = "title"
        static let apsTitleLocalized = "title-loc-key"
        static let apsSubtitle = "subtitle"
        static let apsSubtitleLocalized = "subtitle-loc-key"
        static let apsBody = "body"
        static let apsBodyLocalized = "body-loc-key"
        static let apsCategory = "category"
        static let apsBadge = "badge"
        static let apsContentAvailable = "content-available"
    }
}

public extension SpanEvent where Self == PushNotificationEvent {
    static func push(notification: UNNotification, properties: [String: String] = [:]) throws -> SpanEvent {
        let otelAttributes = properties.reduce(into: [String: AttributeValue]()) {
            $0[$1.key] = AttributeValue.string($1.value)
        }
        return try PushNotificationEvent(notification: notification, attributes: otelAttributes)
    }

    static func push(userInfo: [AnyHashable: Any], properties: [String: String] = [:]) throws -> SpanEvent {
        let otelAttributes = properties.reduce(into: [String: AttributeValue]()) {
            $0[$1.key] = AttributeValue.string($1.value)
        }
        return try PushNotificationEvent(userInfo: userInfo, attributes: otelAttributes)
    }
}
