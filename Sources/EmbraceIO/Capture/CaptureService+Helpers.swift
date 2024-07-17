//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService

@objc public extension CaptureService {
    /// Returns a `URLSessionCaptureService` with the given `URLSessionCaptureService.Options`.
    /// - Parameter options: `URLSessionCaptureService.Options` used to configure the service.
    static func urlSession(
        options: URLSessionCaptureService.Options = URLSessionCaptureService.Options()
    ) -> URLSessionCaptureService {
        return URLSessionCaptureService(options: options)
    }

    /// Returns a `TapCaptureService`.
    static func tap() -> TapCaptureService {
        return TapCaptureService()
    }

    /// Returns a `ViewCaptureService`.
    static func view() -> ViewCaptureService {
        return ViewCaptureService()
    }

    /// Returns a `WebViewCaptureService` with the given `WebViewCaptureService.Options`.
    /// - Parameter options: `WebViewCaptureService.Options` used to configure the service.
    static func webView(
        options: WebViewCaptureService.Options = WebViewCaptureService.Options()
    ) -> WebViewCaptureService {
        return WebViewCaptureService(options: options)
    }

    /// Adds a `LowMemoryWarningCaptureService`.
    static func lowMemoryWarning() -> LowMemoryWarningCaptureService {
        return LowMemoryWarningCaptureService()
    }

    /// Adds a `LowPowerModeCaptureService`.
    static func lowPowerMode() -> LowPowerModeCaptureService {
        return LowPowerModeCaptureService()
    }

    /// Adds a `PushNotificationCaptureService` with the given `PushNotificationCaptureService.Options`.
    /// - Parameter options: `PushNotificationCaptureService.Options` used to configure the service.
    static func pushNotification(
        options: PushNotificationCaptureService.Options = PushNotificationCaptureService.Options()
    ) -> PushNotificationCaptureService {
        return PushNotificationCaptureService(options: options)
    }
}
