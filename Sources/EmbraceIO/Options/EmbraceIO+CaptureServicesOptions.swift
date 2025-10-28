//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
#endif

extension EmbraceIO {

    /// Class used to configure which `CaptureServices` will be installed and their behavior.
    public final class CaptureServicesOptions {
        public let urlSession: URLSessionCaptureService.Options?
        public let tapCapture: TapCaptureService.Options?
        public let viewCapture: ViewCaptureService.Options?
        public let webViewCapture: WebViewCaptureService.Options?
        public let pushNotifications: PushNotificationCaptureService.Options?
        public let lowMemoryWarning: Bool
        public let lowPowerMode: Bool
        public let hangWatchdog: Bool

        /// Initializes a new `EmbraceIO.CaptureServicesOptions` with the given parameters
        /// - Parameters:
        ///   - urlSession: Options to be used for the `URLSessionCaptureService`. If nil is passed, the capture service won't be installed.
        ///   - tapCapture: Options to be used for the `TapCaptureService`. If nil is passed, the capture service won't be installed.
        ///   - viewCapture: Options to be used for the `ViewCaptureService`. If nil is passed, the capture service won't be installed.
        ///   - webViewCapture: Options to be used for the `WebViewCaptureService`. If nil is passed, the capture service won't be installed.
        ///   - pushNotifications: Options to be used for the `PushNotificationCaptureService`. If nil is passed, the capture service won't be installed.
        ///   - lowMemoryWarning: Determines if the `LowMemoryWarningCaptureService` should be installed.
        ///   - lowPowerMode: Determines if the `LowPowerModeCaptureService` should be installed.
        ///   - hangWatchdog: Determines if the `HangCaptureService` should be installed.
        public init(
            urlSession: URLSessionCaptureService.Options? = .init(),
            tapCapture: TapCaptureService.Options? = .init(),
            viewCapture: ViewCaptureService.Options? = .init(),
            webViewCapture: WebViewCaptureService.Options? = .init(),
            pushNotifications: PushNotificationCaptureService.Options? = nil,
            lowMemoryWarning: Bool = true,
            lowPowerMode: Bool = true,
            hangWatchdog: Bool = true
        ) {
            self.urlSession = urlSession
            self.tapCapture = tapCapture
            self.viewCapture = viewCapture
            self.webViewCapture = webViewCapture
            self.pushNotifications = pushNotifications
            self.lowMemoryWarning = lowMemoryWarning
            self.lowPowerMode = lowPowerMode
            self.hangWatchdog = hangWatchdog
        }
    }
}
