//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import UserNotifications
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

@objc public extension EmbraceOTelSignalsHandler {

    /// Adds a PushNotification span event to the current Embrace session using the data from the given `UNNotification`.
    /// - Parameters:
    ///   - notification: The `UNNotification` received by the app.
    ///   - timestamp: Timestamp of the event.
    ///   - attributes: Attributes of the event.
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification.
    /// - Throws: `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    /// - Throws: `PushNotificationError.invalidPayload` if the `aps` object is not present in the `userInfo` of the `UNNotification`.
    @objc func addPushNotificationEvent(
        notification: UNNotification,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        captureData: Bool = true
    ) throws {
        var userInfo: [AnyHashable: Any] = [:]
        #if !os(tvOS)
            userInfo = notification.request.content.userInfo
        #endif

        try addPushNotificationEvent(
            userInfo: userInfo,
            timestamp: timestamp,
            attributes: attributes,
            captureData: captureData
        )
    }

    /// Adds a PushNotification span event to the current Embrace session using the `userInfo` dictionary from a push notification.
    /// - Parameters:
    ///   - userInfo: The `userInfo` dictionary from a push notification.
    ///   - timestamp: Timestamp of the event.
    ///   - attributes: Attributes of the event.
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification.
    /// - Throws: `EmbraceOTelError.invalidSession` if there is not active Embrace session.
    /// - Throws: `EmbraceOTelError.spanEventLimitReached` if the limit hass ben reached for the given span even type.
    /// - Throws: `PushNotificationError.invalidPayload` if the `aps` object is not present in the `userInfo` of the `UNNotification`.
    @objc func addPushNotificationEvent(
        userInfo: [AnyHashable: Any],
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        captureData: Bool = true
    ) throws {

        guard let span = sessionController?.currentSessionSpan else {
            throw EmbraceOTelError.invalidSession
        }

        guard limiter.shouldAddSessionEvent(ofType: .pushNotification) else {
            throw EmbraceOTelError.spanEventLimitReached("PushNotification event limit reached!")
        }

        // find aps key
        guard let apsDict = userInfo[Constants.apsRootKey] as? [AnyHashable: Any] else {
            throw PushNotificationError.invalidPayload("Couldn't find aps object!")
        }

        let dict = Self.parse(apsDict: apsDict, captureData: captureData)
        let sanitized = sanitizer.sanitizeSpanEventAttributes(attributes)
        let finalAttributes = sanitized.merging(dict) { (current, _) in current }

        let event = EmbraceSpanEvent(
            name: SpanEventSemantics.PushNotification.name,
            type: .pushNotification,
            timestamp: timestamp,
            attributes: finalAttributes
        )

        span.addSessionEvent(event)
    }

    // MARK: Internal
    static func parse(apsDict: [AnyHashable: Any], captureData: Bool) -> [String: String] {

        var dict: [String: String] = [:]

        // set types
        dict[SpanEventSemantics.keyEmbraceType] = EmbraceType.pushNotification.rawValue
        dict[SpanEventSemantics.PushNotification.keyType] =
            isSilent(userInfo: apsDict)
            ? SpanEventSemantics.PushNotification.silentType
            : SpanEventSemantics.PushNotification.notificationType

        // capture data if enabled
        if captureData {
            var title: String?
            var subtitle: String?
            var body: String?

            if let alertData = apsDict[Constants.apsAlert] as? [AnyHashable: Any] {
                title =
                    alertData[Constants.apsTitle] as? String
                    ?? alertData[Constants.apsTitleLocalized] as? String

                subtitle =
                    alertData[Constants.apsSubtitle] as? String
                    ?? alertData[Constants.apsSubtitleLocalized] as? String

                body =
                    alertData[Constants.apsBody] as? String
                    ?? alertData[Constants.apsBodyLocalized] as? String
            }

            let category = apsDict[Constants.apsCategory] as? String
            let badge = apsDict[Constants.apsBadge] as? Int

            if let title = title {
                dict[SpanEventSemantics.PushNotification.keyTitle] = title
            }

            if let subtitle = subtitle {
                dict[SpanEventSemantics.PushNotification.keySubtitle] = subtitle
            }

            if let body = body {
                dict[SpanEventSemantics.PushNotification.keyBody] = body
            }

            if let category = category {
                dict[SpanEventSemantics.PushNotification.keyCategory] = category
            }

            if let badge = badge {
                dict[SpanEventSemantics.PushNotification.keyBadge] = String(badge)
            }
        }

        return dict
    }

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

extension OTelSignalsHandler {
    func addPushNotificationEvent(
        notification: UNNotification,
        timestamp: Date = Date(),
        attributes: [String: String] = [:],
        captureData: Bool = true
    ) throws {
        guard let internalHandler = self as? EmbraceOTelSignalsHandler else {
            return
        }

        try internalHandler.addPushNotificationEvent(
            notification: notification,
            timestamp: timestamp,
            attributes: attributes,
            captureData: captureData
        )
    }
}
