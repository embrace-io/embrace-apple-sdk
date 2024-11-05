//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import UserNotifications
import EmbraceOTelInternal

class UNUserNotificationCenterDelegateProxy: NSObject {
    weak var originalDelegate: UNUserNotificationCenterDelegate?
    let captureData: Bool

    init(captureData: Bool) {
        self.captureData = captureData
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return true
        }
        return false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) {
            return self
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }
        return nil
    }
}

extension UNUserNotificationCenterDelegateProxy: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {

        // generate span event
        if let event = try? PushNotificationEvent(notification: notification, captureData: captureData) {
            Embrace.client?.add(event: event)
        }

        // call original
        if #available(iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            originalDelegate?.userNotificationCenter?(
                center,
                willPresent: notification,
                withCompletionHandler: completionHandler
            )
                ?? completionHandler(.list)
        } else {
            originalDelegate?.userNotificationCenter?(
                center,
                willPresent: notification,
                withCompletionHandler: completionHandler
            )
                ?? completionHandler(.alert)
        }
    }
#if !os(tvOS)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {

        // generate span event
        if let event = try? PushNotificationEvent(notification: response.notification, captureData: captureData) {
            Embrace.client?.add(event: event)
        }

        // call original
        originalDelegate?.userNotificationCenter?(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler
        )
            ?? completionHandler()
    }

#if !os(watchOS)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        // call original
        originalDelegate?.userNotificationCenter?(center, openSettingsFor: notification)
    }
#endif
#endif
}
