//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import UIKit
import EmbraceCommon

public final class TapCaptureService: InstalledCaptureService {
    private let swizzler: UIWindowSendEventSwizzler
    private let handler: TapCaptureServiceHandler
    private let lock: NSLocking
    private var didInstall: Bool
    private(set) var captureServiceState: CaptureServiceState {
        didSet {
            handler.changedState(to: captureServiceState)
        }
    }

    public convenience init() {
        let handler = DefaultTapCaptureServiceHandler.create()
        self.init(lock: NSLock(),
                  handler: handler,
                  swizzlerProvider: DefaultUIWindowSwizzlerProvider())
    }

    private init(lock: NSLocking,
                 handler: TapCaptureServiceHandler,
                 swizzlerProvider: UIWindowSwizzlerProvider) {
        self.lock = lock
        self.handler = handler
        self.swizzler = swizzlerProvider.get(usingHandler: handler)
        self.didInstall = false
        self.captureServiceState = .uninstalled
    }

    public func install(context: CaptureServiceContext) {
        guard captureServiceState == .uninstalled else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        guard !didInstall else {
            return
        }
        do {
            try swizzler.install()
            didInstall = true
        } catch let exception {
            ConsoleLog.error("An error ocurred while swizzling UIWindow.sendEvent: %@", exception.localizedDescription)
        }
    }

    public func uninstall() {
        captureServiceState = .uninstalled
    }

    public func start() {
        captureServiceState = .listening
    }

    public func stop() {
        captureServiceState = .paused
    }
}

class UIWindowSendEventSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIWindow, Selector, UIEvent) -> Void
    typealias BlockImplementationType = @convention(block) (UIWindow, UIEvent) -> Void
    static var selector: Selector = #selector(
        UIWindow.sendEvent(_:)
    )

    private let handler: TapCaptureServiceHandler
    var baseClass: AnyClass = UIWindow.self

    init(handler: TapCaptureServiceHandler) {
        self.handler = handler
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak handler = self.handler] uiWindow, uiEvent -> Void in
                handler?.handleCapturedEvent(uiEvent)
                originalImplementation(uiWindow, UIWindowSendEventSwizzler.selector, uiEvent)
            }
        }
    }
}

#endif
