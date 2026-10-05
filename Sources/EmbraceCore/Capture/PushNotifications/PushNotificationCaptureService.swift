//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import UserNotifications

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceCaptureService
#endif

/// Service that generates OpenTelemetry span events when notifications are received through the `UNUserNotificationCenter`.
public final class PushNotificationCaptureService: CaptureService {

    /// The options used to configure this service.
    public let options: PushNotificationCaptureService.Options
    private let lock: NSLocking
    private var swizzlers: [any Swizzlable] = []
    var proxy: UNUserNotificationCenterDelegateProxy

    /// Creates a new `PushNotificationCaptureService` with the given options.
    /// - Parameters:
    ///   - options: The options used to configure the service.
    ///   - lock: Lock used to synchronize swizzling. Exposed for testing.
    public init(
        options: PushNotificationCaptureService.Options = PushNotificationCaptureService.Options(),
        lock: NSLocking = NSLock()
    ) {
        self.options = options
        self.lock = lock
        self.proxy = UNUserNotificationCenterDelegateProxy(captureData: options.captureData)
    }

    public override func onInstall() {
        lock.lock()
        defer {
            lock.unlock()
        }

        proxy.otel = otel
        initializeSwizzlers()

        swizzlers.forEach {
            do {
                try $0.install()
            } catch let exception {
                Embrace.logger.error("Capture service couldn't be installed: \(exception.localizedDescription)")
            }
        }

        // Run any delegate the app set before Embrace started through the swizzled setter.
        UNUserNotificationCenter.current().delegate = UNUserNotificationCenter.current().delegate
    }

    private func initializeSwizzlers() {
        swizzlers.append(UNUserNotificationCenterSetDelegateSwizzler(proxy: proxy))
    }
}

struct UNUserNotificationCenterSetDelegateSwizzler: Swizzlable {
    typealias ImplementationType =
        @convention(c) (UNUserNotificationCenter, Selector, UNUserNotificationCenterDelegate?)
        -> Void
    typealias BlockImplementationType =
        @convention(block) (UNUserNotificationCenter, UNUserNotificationCenterDelegate?)
        -> Void
    static var selector: Selector = #selector(setter: UNUserNotificationCenter.delegate)
    var baseClass: AnyClass
    let proxy: UNUserNotificationCenterDelegateProxy

    init(proxy: UNUserNotificationCenterDelegateProxy, baseClass: AnyClass = UNUserNotificationCenter.self) {
        self.baseClass = baseClass
        self.proxy = proxy
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { center, delegate in
                // Setting the proxy itself (e.g. re-assigning the current delegate) must not make the proxy forward to itself.
                if !(delegate is UNUserNotificationCenterDelegateProxy) {
                    proxy.originalDelegate = delegate
                }
                originalImplementation(center, Self.selector, proxy)
            }
        }
    }
}
