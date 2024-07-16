//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import UserNotifications
import EmbraceCommon
import EmbraceOTel
import EmbraceCaptureService
import UIKit

/// Automatically generates span events when notifications are received through the `UNUserNotificationCenter`.
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
// swiftlint:enable line_length
