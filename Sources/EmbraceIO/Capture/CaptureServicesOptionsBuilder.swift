//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceCaptureService
#endif

/// Class used to create and customize an `EmbraceIO.CaptureServicesOptions` instance.
public class CaptureServicesOptionsBuilder: NSObject {
    private var map: [EmbraceCaptureService: Any] = [:]
    private var customServices: [CaptureService] = []

    /// Returns the `EmbraceIO.CaptureServicesOptions` instance generated with this builder.
    public func build() -> EmbraceIO.CaptureServicesOptions {

        let urlSession = map[.urlSession] as? URLSessionCaptureService.Options
        let tap = map[.tap] as? TapCaptureService.Options
        let view = map[.view] as? ViewCaptureService.Options
        let webView = map[.webView] as? WebViewCaptureService.Options
        let pushNotification = map[.pushNotification] as? PushNotificationCaptureService.Options
        let lowMemoryWarning = (map[.lowMemoryWarning] as? Bool) ?? false
        let lowPowerMode = (map[.lowPowerMode] as? Bool) ?? false
        let hang = (map[.hang] as? Bool) ?? false

        return EmbraceIO.CaptureServicesOptions(
            urlSession: urlSession,
            tap: tap,
            view: view,
            webView: webView,
            pushNotification: pushNotification,
            lowMemoryWarning: lowMemoryWarning,
            lowPowerMode: lowPowerMode,
            hang: hang,
            customServices: customServices
        )
    }

    /// Adds the default `CaptureServices` using their corresponding default options.
    /// The default services are: `.urlSession`, `.tap`, `.view`, `webView`, `.lowMemoryWarning` and `.lowPowerMode`.
    /// - Note: Any existing `CaptureService` previously added will not get replaced by calling this method.
    @discardableResult
    public func addDefaults() -> Self {
        // url session
        if map[.urlSession] == nil {
            map[.urlSession] = URLSessionCaptureService.Options()
        }

        #if canImport(UIKit) && !os(watchOS)
            // tap
            if map[.tap] == nil {
                map[.tap] = TapCaptureService.Options()
            }

            // view
            if map[.view] == nil {
                map[.view] = ViewCaptureService.Options()
            }
        #endif

        #if canImport(WebKit)
            // web view
            if map[.webView] == nil {
                map[.webView] = WebViewCaptureService.Options()
            }
        #endif

        // low memory warning
        if map[.lowMemoryWarning] == nil {
            map[.lowMemoryWarning] = true
        }

        // low power mode
        if map[.lowPowerMode] == nil {
            map[.lowPowerMode] = true
        }

        return self
    }

    /// Adds a new `URLSessionCaptureService` with the given options.
    /// - Note: If there was another `URLSessionCaptureService` previously added, it will be replaced with the new one.
    @discardableResult
    public func addUrlSessionCaptureService(withOptions options: URLSessionCaptureService.Options) -> Self {
        map[.urlSession] = options
        return self
    }

    #if canImport(UIKit) && !os(watchOS)
        /// Adds a new `TapCaptureService` with the given options.
        /// - Note: If there was another `TapCaptureService` previously added, it will be replaced with the new one.
        @discardableResult
        public func addTapCaptureService(withOptions options: TapCaptureService.Options) -> Self {
            map[.tap] = options
            return self
        }

        /// Adds a new `ViewCaptureService` with the given options.
        /// - Note: If there was another `ViewCaptureService` previously added, it will be replaced with the new one.
        @discardableResult
        public func addViewCaptureService(withOptions options: ViewCaptureService.Options) -> Self {
            map[.view] = options
            return self
        }
    #endif

    #if canImport(WebKit)
        /// Adds a new `WebViewCaptureService` with the given options.
        /// - Note: If there was another `WebViewCaptureService` previously added, it will be replaced with the new one.
        @discardableResult
        public func addWebViewCaptureService(withOptions options: WebViewCaptureService.Options) -> Self {
            map[.webView] = options
            return self
        }
    #endif

    /// Adds a new `PushNotificationCaptureService` with the given options.
    /// - Note: If there was another `PushNotificationCaptureService` previously added, it will be replaced with the new one.
    @discardableResult
    public func addPushNotificationCaptureService(withOptions options: PushNotificationCaptureService.Options) -> Self {
        map[.pushNotification] = options
        return self
    }

    /// Adds a new `LowMemoryWarningCaptureService`.
    /// - Note: If there was another `LowMemoryWarningCaptureService` previously added, it will be replaced with the new one.
    @discardableResult
    public func addLowMemoryWarningCaptureService() -> Self {
        map[.lowMemoryWarning] = true
        return self
    }

    /// Adds a new `LowPowerModeCaptureService`.
    /// - Note: If there was another `LowPowerModeCaptureService` previously added, it will be replaced with the new one.
    @discardableResult
    public func addLowPowerModeCaptureService() -> Self {
        map[.lowPowerMode] = true
        return self
    }

    /// Adds a new `HangCaptureService`.
    /// - Note: If there was another `HangCaptureService` previously added, it will be replaced with the new one.
    @discardableResult
    public func addHangCaptureService() -> Self {
        map[.hang] = true
        return self
    }

    /// Adds the given custom `CaptureService`.
    /// - Note: If there was another `CaptureService` already added of the same type, it will be replaced with the new one.
    @discardableResult
    public func add(_ service: CaptureService) -> Self {
        remove(ofType: type(of: service))
        customServices.append(service)

        return self
    }

    /// Removes a previously added `CaptureService` of the given type, if any.
    /// - Parameter type: Type of the `CaptureService` to remove.
    @discardableResult
    public func remove(ofType type: AnyClass) -> Self {

        if type == URLSessionCaptureService.self {
            map[.urlSession] = nil
        }

        #if canImport(UIKit) && !os(watchOS)
            if type == TapCaptureService.self {
                map[.tap] = nil
            }

            if type == ViewCaptureService.self {
                map[.view] = nil
            }
        #endif

        #if canImport(WebKit)
            if type == WebViewCaptureService.self {
                map[.webView] = nil
            }
        #endif

        if type == PushNotificationCaptureService.self {
            map[.pushNotification] = nil
        }

        if type == LowPowerModeCaptureService.self {
            map[.lowMemoryWarning] = nil
        }

        if type == LowPowerModeCaptureService.self {
            map[.lowPowerMode] = nil
        }

        if type == HangCaptureService.self {
            map[.hang] = nil
        }

        customServices.removeAll(where: { $0.isKind(of: type) })

        return self
    }

    /// Removes a previously added `EmbraceCaptureService`.
    /// - Parameter embraceType: The `EmbraceCaptureService` to remove.
    @discardableResult
    public func remove(embraceType: EmbraceCaptureService) -> Self {
        map[embraceType] = nil
        return self
    }
}
