//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import UserNotifications

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceCaptureService
#endif

/// Service that generates OpenTelemetry span events when notifications are received through the `UNUserNotificationCenter`.
@objc public final class PushNotificationCaptureService: CaptureService {

    @objc public let options: PushNotificationCaptureService.Options
    private let lock: NSLocking
    private var swizzlers: [any Swizzlable] = []
    var proxy: UNUserNotificationCenterDelegateProxy

    @objc public convenience init(options: PushNotificationCaptureService.Options) {
        self.init(options: options, lock: NSLock())
    }

    public convenience override init() {
        self.init(lock: NSLock())
    }

    init(
        options: PushNotificationCaptureService.Options = PushNotificationCaptureService.Options(),
        lock: NSLocking
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

        // read the current delegate before swizzling, since the swizzled getter returns the proxied delegate
        let currentDelegate = UNUserNotificationCenter.current().delegate

        initializeSwizzlers()

        swizzlers.forEach {
            do {
                try $0.install()
            } catch let exception {
                Embrace.logger.error("Capture service couldn't be installed: \(exception.localizedDescription)")
            }
        }

        // call set delegate manually to set the proxy
        UNUserNotificationCenter.current().delegate = currentDelegate
    }

    private func initializeSwizzlers() {
        swizzlers.append(UNUserNotificationCenterSetDelegateSwizzler(proxy: proxy))
        swizzlers.append(UNUserNotificationCenterGetDelegateSwizzler(proxy: proxy))
    }
}

// swiftlint:disable line_length
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

/// Hides the proxy from callers of `UNUserNotificationCenter.delegate` by returning the delegate it forwards to.
/// This way, code that reads the delegate to re-assign or wrap it never feeds the proxy back into itself.
struct UNUserNotificationCenterGetDelegateSwizzler: Swizzlable {
    typealias ImplementationType =
        @convention(c) (UNUserNotificationCenter, Selector) -> UNUserNotificationCenterDelegate?
    typealias BlockImplementationType =
        @convention(block) (UNUserNotificationCenter) -> UNUserNotificationCenterDelegate?
    static var selector: Selector = #selector(getter: UNUserNotificationCenter.delegate)
    var baseClass: AnyClass
    let proxy: UNUserNotificationCenterDelegateProxy

    init(proxy: UNUserNotificationCenterDelegateProxy, baseClass: AnyClass = UNUserNotificationCenter.self) {
        self.baseClass = baseClass
        self.proxy = proxy
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { center in
                let delegate = originalImplementation(center, Self.selector)
                return delegate is UNUserNotificationCenterDelegateProxy ? proxy.originalDelegate : delegate
            }
        }
    }
}
// swiftlint:enable line_length
