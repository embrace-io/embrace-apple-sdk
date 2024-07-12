//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTel
import Foundation
import UserNotifications

public struct PushNotificationEvent: SpanEvent {
    public let name: String
    public let timestamp: Date
    public private(set) var attributes: [String: AttributeValue]

    /// Returns a span event on using the data from the given `UNNotification`
    /// - Parameters:
    ///   - notification: The `UNNotification` received by the app
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification
    /// - Throws: `PushNotificationError.invalidPayload` if the `aps` object is not present in the `userInfo` of the `UNNotification`.
    init(notification: UNNotification,
         timestamp: Date = Date(),
         attributes: [String: AttributeValue] = [:],
         captureData: Bool = true
    ) throws {
        try self.init(userInfo: notification.request.content.userInfo, attributes: attributes, captureData: captureData)
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
        guard let apsDict = userInfo[Constants.rootKey] as? [AnyHashable: Any] else {
            throw PushNotificationError.invalidPayload("Couldn't find aps object!")
        }

        self.name = Constants.eventName
        self.timestamp = timestamp

        var dict = Self.parse(apsDict: apsDict, captureData: captureData)
        self.attributes = attributes.merging(dict) { (current, _) in current }
    }

    static func parse(apsDict: [AnyHashable: Any], captureData: Bool) -> [String: AttributeValue] {

        var dict: [String: AttributeValue] = [:]

        // set types
        dict["emb.type"] = .string(Constants.eventType)
        dict[Constants.keyType] =
            isSilent(userInfo: apsDict) ?
            .string(Constants.silentType) :
            .string(Constants.notificationType)

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
                dict[Constants.keyTitle] = .string(title)
            }

            if let subtitle = subtitle {
                dict[Constants.keySubtitle] = .string(subtitle)
            }

            if let body = body {
                dict[Constants.keyBody] = .string(body)
            }

            if let category = category {
                dict[Constants.keyCategory] = .string(category)
            }

            if let badge = badge {
                dict[Constants.keyBadge] = .int(badge)
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
        static let rootKey = "aps"
        static let eventName = "emb-push-notification"
        static let eventType = "sys.push_notification"

        static let notificationType = "notif"
        static let silentType = "silent"

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

        static let keyType = "notification.type"
        static let keyTitle = "notification.title"
        static let keySubtitle = "notification.subtitle"
        static let keyBody = "notification.body"
        static let keyCategory = "notification.category"
        static let keyBadge = "notification.badge"
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
