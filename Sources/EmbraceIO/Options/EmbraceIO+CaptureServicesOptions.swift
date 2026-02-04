//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceCaptureService
#endif

extension EmbraceIO {

    /// Class used to configure which `CaptureServices` will be installed and their behavior.
    /// Refer to `CaptureServicesOptionsBuilder` if you want a custom setup.
    public final class CaptureServicesOptions {
        let urlSession: URLSessionCaptureService.Options?
        let tap: TapCaptureService.Options?
        let view: ViewCaptureService.Options?
        let webView: WebViewCaptureService.Options?
        let pushNotification: PushNotificationCaptureService.Options?
        let lowMemoryWarning: Bool
        let lowPowerMode: Bool
        let hang: Bool
        let customServices: [CaptureService]

        public class func `default`() -> EmbraceIO.CaptureServicesOptions {
            return CaptureServicesOptions()
        }

        internal init(
            urlSession: URLSessionCaptureService.Options? = .init(),
            tap: TapCaptureService.Options? = .init(),
            view: ViewCaptureService.Options? = .init(),
            webView: WebViewCaptureService.Options? = .init(),
            pushNotification: PushNotificationCaptureService.Options? = nil,
            lowMemoryWarning: Bool = true,
            lowPowerMode: Bool = true,
            hang: Bool = false,
            customServices: [CaptureService] = []
        ) {
            self.urlSession = urlSession
            self.tap = tap
            self.view = view
            self.webView = webView
            self.pushNotification = pushNotification
            self.lowMemoryWarning = lowMemoryWarning
            self.lowPowerMode = lowPowerMode
            self.hang = hang
            self.customServices = customServices
        }

        var list: [CaptureService] {
            var services: [CaptureService] = []

            // url session
            if let urlSessionOptions = urlSession {
                services.append(URLSessionCaptureService(options: urlSessionOptions))
            }

            // tap
            if let tapOptions = tap {
                services.append(TapCaptureService(options: tapOptions))
            }

            if let viewOptions = view {
                services.append(ViewCaptureService(options: viewOptions))
            }

            if let webViewOptions = webView {
                services.append(WebViewCaptureService(options: webViewOptions))
            }

            if let pushNotificationOptions = pushNotification {
                services.append(PushNotificationCaptureService(options: pushNotificationOptions))
            }

            if lowMemoryWarning {
                services.append(LowMemoryWarningCaptureService())
            }

            if lowPowerMode {
                services.append(LowPowerModeCaptureService())
            }

            if hang {
                services.append(HangCaptureService())
            }

            services.append(contentsOf: customServices)

            return services
        }
    }
}
