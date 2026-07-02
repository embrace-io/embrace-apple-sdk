//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import UserNotifications

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Push Notifications
extension EmbraceIO {

    /// Adds a PushNotification span event to the current Embrace session using the data from the given `UNNotification`.
    /// If no session is active, the payload is invalid, or the event limit has been reached, the event is dropped and a warning is logged.
    /// - Parameters:
    ///   - notification: The `UNNotification` received by the app.
    ///   - timestamp: Timestamp of the event.
    ///   - attributes: Attributes of the event.
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification.
    public func addPushNotificationEvent(
        notification: UNNotification,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        captureData: Bool = true
    ) {
        Embrace.client?.otel.addPushNotificationEvent(
            notification: notification,
            timestamp: timestamp,
            attributes: attributes,
            captureData: captureData
        )
    }

    /// Adds a PushNotification span event to the current Embrace session using the `userInfo` dictionary from a push notification.
    /// If no session is active, the payload is invalid, or the event limit has been reached, the event is dropped and a warning is logged.
    /// - Parameters:
    ///   - userInfo: The `userInfo` dictionary from a push notification.
    ///   - timestamp: Timestamp of the event.
    ///   - attributes: Attributes of the event.
    ///   - captureData: Whether or not Embrace should parse the data inside the push notification.
    public func addPushNotificationEvent(
        userInfo: [AnyHashable: Any],
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:],
        captureData: Bool = true
    ) {
        Embrace.client?.otel.addPushNotificationEvent(
            userInfo: userInfo,
            timestamp: timestamp,
            attributes: attributes,
            captureData: captureData
        )
    }
}
