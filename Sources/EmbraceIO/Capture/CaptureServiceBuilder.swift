//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
#endif

/// Class used to build the list of `CaptureServices` to be used by the `Embrace` instance.
public class CaptureServiceBuilder {
    private var services: [CaptureService] = []

    /// Returns the list of `CaptureServices` generated with this builder.
    public func build() -> [CaptureService] {
        return services
    }

    /// Adds the given `CaptureService`.
    /// - Note: If there was another `CaptureService` already added of the same type, it will be replaced with the new one.
    @discardableResult
    public func add(_ service: CaptureService) -> Self {
        remove(ofType: type(of: service))
        services.append(service)

        return self
    }

    /// Removes a previously added `CaptureService` of the given type, if any.
    /// - Parameter type: Type of the `CaptureService` to remove.
    @discardableResult
    public func remove(ofType: AnyClass) -> Self {
        services.removeAll(where: { type(of: $0) == ofType })

        return self
    }

    /// Adds the default `CaptureServices` using their corresponding default options.
    /// The default services are: `URLSessionCaptureService`, `TapCaptureService`, `ViewCaptureService`,
    /// `WebViewCaptureService`, `LowMemoryWarningCaptureService` and `LowPowerModeCaptureService`.
    /// - Note: Any existing `CaptureService` previously added will not get replaced by calling this method.
    @discardableResult
    public func addDefaults() -> Self {
        // url session
        if !services.contains(where: { $0 is URLSessionCaptureService }) {
            add(.urlSession())
        }

        #if canImport(UIKit) && !os(watchOS)
            // tap
            if !services.contains(where: { $0 is TapCaptureService }) {
                add(.tap())
            }

            // view
            if !services.contains(where: { $0 is ViewCaptureService }) {
                add(.view())
            }
        #endif

        #if canImport(WebKit)
            // web view
            if !services.contains(where: { $0 is WebViewCaptureService }) {
                add(.webView())
            }
        #endif

        // low memory
        if !services.contains(where: { $0 is LowMemoryWarningCaptureService }) {
            add(.lowMemoryWarning())
        }

        // low power
        if !services.contains(where: { $0 is LowPowerModeCaptureService }) {
            add(.lowPowerMode())
        }

        // hang
        if !services.contains(where: { $0 is HangCaptureService }) {
            add(.hangWatchdog())
        }

        return self
    }
}
