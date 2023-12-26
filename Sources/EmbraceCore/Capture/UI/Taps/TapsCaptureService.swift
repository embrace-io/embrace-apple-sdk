//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import UIKit
import EmbraceCommon

final class TapCaptureService: Swizzlable {
    typealias ImplementationType = @convention(c) (UIWindow, Selector, UIEvent) -> Void
    typealias BlockImplementationType = @convention(block) (UIWindow, UIEvent) -> Void
    static var selector: Selector = #selector(
        UIWindow.sendEvent(_:)
    )

    private let handler: TapCaptureServiceHandler
    private let lock: NSLocking
    private var didInstall: Bool
    private(set) var captureServiceState: CaptureServiceState {
        didSet {
            handler.changedState(to: captureServiceState)
        }
    }

    var baseClass: AnyClass = UIWindow.self

    init(lock: NSLocking = NSLock(),
         handler: TapCaptureServiceHandler = DefaultTapCaptureServiceHandler.create()) {
        self.lock = lock
        self.handler = handler
        self.didInstall = false
        self.captureServiceState = .uninstalled
    }
}

extension TapCaptureService: InstalledCaptureService {
    func install(context: CaptureServiceContext) {
        guard captureServiceState == .uninstalled else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        guard !didInstall else {
            return
        }
        didInstall = true
        do {
            try swizzleInstanceMethod { originalImplementation in
                return { [weak self] uiWindow, uiEvent -> Void in
                    self?.handler.handleCapturedEvent(uiEvent)
                    originalImplementation(uiWindow, TapCaptureService.selector, uiEvent)
                }
            }
        } catch let exception {
            ConsoleLog.error("An error ocurred while swizzling UIWindow.sendEvent: %@", exception.localizedDescription)
        }
    }

    func uninstall() {
        captureServiceState = .uninstalled
    }

    func start() {
        captureServiceState = .listening
    }

    func stop() {
        captureServiceState = .paused
    }
}
#endif
