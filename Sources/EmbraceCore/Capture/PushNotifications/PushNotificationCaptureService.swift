//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if os(iOS)
import Foundation
import UserNotifications
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceCaptureService

import UIKit
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

        guard state == .uninstalled else {
            return
        }

        initializeSwizzlers()

        swizzlers.forEach {
            do {
                try $0.install()
            } catch let exception {
                Embrace.logger.error("Capture service couldn't be installed: \(exception.localizedDescription)")
            }
        }

        // call set delegate manually to set the proxy
        UNUserNotificationCenter.current().delegate = UNUserNotificationCenter.current().delegate
    }

    private func initializeSwizzlers() {
        swizzlers.append(UNUserNotificationCenterSetDelegateSwizzler(proxy: proxy))
        swizzlers.append(AppDelegateDidReceiveRemoteNotificationSwizzler(captureData: options.captureData))
    }
}

// swiftlint:disable line_length
struct UNUserNotificationCenterSetDelegateSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UNUserNotificationCenter, Selector, UNUserNotificationCenterDelegate) -> Void
    typealias BlockImplementationType = @convention(block) (UNUserNotificationCenter, UNUserNotificationCenterDelegate) -> Void
    static var selector: Selector = #selector(setter: UNUserNotificationCenter.delegate)
    var baseClass: AnyClass
    let proxy: UNUserNotificationCenterDelegateProxy

    init(proxy: UNUserNotificationCenterDelegateProxy, baseClass: AnyClass = UNUserNotificationCenter.self) {
        self.baseClass = baseClass
        self.proxy = proxy
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { webView, delegate in
                proxy.originalDelegate = delegate
                originalImplementation(webView, Self.selector, proxy)
            }
        }
    }
}

struct AppDelegateDidReceiveRemoteNotificationSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (AnyObject, Selector, UIApplication, [AnyHashable: Any], (UIBackgroundFetchResult) -> Void) -> Void
    typealias BlockImplementationType = @convention(block) (AnyObject, UIApplication, [AnyHashable: Any], (UIBackgroundFetchResult) -> Void) -> Void

    static var selector: Selector {
        return #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    }

    var baseClass: AnyClass {
        guard let delegate = UIApplication.shared.delegate else {
            return UIApplication.self
        }
        return type(of: delegate)
    }

    private let captureData: Bool

    init(captureData: Bool) {
        self.captureData = captureData
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { uiApplicationDelegate, application, userInfo, completionHandler in
                if let event = try? PushNotificationEvent(userInfo: userInfo, captureData: self.captureData) {
                    Embrace.client?.add(event: event)
                }
                originalImplementation(uiApplicationDelegate, Self.selector, application, userInfo, completionHandler)
            }
        }
    }
}
// swiftlint:enable line_length
#endif
