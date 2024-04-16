//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)
import UIKit
import EmbraceCaptureService
import EmbraceCommon
import EmbraceOTel

@objc public final class TapCaptureService: CaptureService {

    private var swizzler: UIWindowSendEventSwizzler?
    private let lock: NSLocking

    public override init() {
        self.lock = NSLock()
    }

    override public func onInstall() {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard state == .uninstalled else {
            return
        }

        do {
            swizzler = UIWindowSendEventSwizzler()
            swizzler?.onEvent = { [weak self] event in
                self?.handleCapturedEvent(event)
            }

            try swizzler?.install()
        } catch let exception {
            ConsoleLog.error("An error ocurred while swizzling UIWindow.sendEvent: %@", exception.localizedDescription)
        }
    }

    func handleCapturedEvent(_ event: UIEvent) {
        guard state == .active else {
            return
        }

        guard event.type == .touches,
              let allTouches = event.allTouches,
              let touch = allTouches.first,
              touch.phase == .began,
              let target = touch.view else {
            return
        }

        let screenView = target.window
        var point = CGPoint()

        if shouldRecordCoordinates(from: target) {
            point = touch.location(in: screenView)
        }

        let accessibilityIdentifier = target.accessibilityIdentifier
        let targetClass = type(of: target)

        let viewName = accessibilityIdentifier ?? String(describing: targetClass)

        let event = RecordingSpanEvent(
            name: "emb-ui-tap",
            timestamp: Date(),
            attributes: [
                "view.name": .string(viewName),
                "tap.coords": .string(point.toString()),
                "emb.type": .string("ux.tap")
            ]
        )

        add(event: event)

        ConsoleLog.trace("Captured tap at \(point) on: \(viewName)")
    }

    func shouldRecordCoordinates(from target: AnyObject?) -> Bool {
        guard let keyboardViewClass = NSClassFromString("UIKeyboardLayout"),
              let keyboardWindowClass = NSClassFromString("UIRemoteKeyboardWindow"),
              let target = target
        else {
            return false
        }

        return !(target.isKind(of: keyboardViewClass) || target.isKind(of: keyboardWindowClass))
    }
}

class UIWindowSendEventSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIWindow, Selector, UIEvent) -> Void
    typealias BlockImplementationType = @convention(block) (UIWindow, UIEvent) -> Void
    static var selector: Selector = #selector(
        UIWindow.sendEvent(_:)
    )

    var baseClass: AnyClass = UIWindow.self

    var onEvent: ((UIEvent) -> Void)?

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] uiWindow, uiEvent -> Void in
                self?.onEvent?(uiEvent)
                originalImplementation(uiWindow, UIWindowSendEventSwizzler.selector, uiEvent)
            }
        }
    }
}

#endif
