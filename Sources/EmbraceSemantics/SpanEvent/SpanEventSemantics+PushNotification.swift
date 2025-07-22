//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let pushNotification = SpanEventType(system: "push_notification")
}

extension SpanEventSemantics {
    public struct PushNotification {
        public static let name = "emb-push-notification"

        public static let keyType = "notification.type"
        public static let keyTitle = "notification.title"
        public static let keySubtitle = "notification.subtitle"
        public static let keyBody = "notification.body"
        public static let keyCategory = "notification.category"
        public static let keyBadge = "notification.badge"

        public static let notificationType = "notif"
        public static let silentType = "silent"
    }
}

extension SpanType {
    @available(
        *,
        deprecated,
        renamed: "SpanEventType.pushNotification",
        message: "Has been moved to `SpanEventType.pushNotification`"
    )
    public static let pushNotification = SpanEventType(system: "push_notification")
}
