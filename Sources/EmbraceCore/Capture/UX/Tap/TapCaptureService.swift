//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)
import UIKit
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceSemantics
import OpenTelemetryApi

/// Service that generates OpenTelemetry span events for taps on the screen.
/// Note that any taps done on a keyboard view will be automatically ignored.
@objc(EMBTapCaptureService)
public final class TapCaptureService: CaptureService {

    public let options: TapCaptureService.Options

    private var swizzler: UIWindowSendEventSwizzler?
    private let lock: NSLocking

    @objc public convenience init(options: TapCaptureService.Options = TapCaptureService.Options()) {
        self.init(options: options, lock: NSLock())
    }

    init(options: TapCaptureService.Options, lock: NSLock) {
        self.options = options
        self.lock = lock
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
            Embrace.logger.error("An error ocurred while swizzling UIWindow.sendEvent: \(exception.localizedDescription)")
        }
    }

    func handleCapturedEvent(_ event: UIEvent) {
        guard state == .active else {
            return
        }

        // get touch data
        guard event.type == .touches,
              let allTouches = event.allTouches,
              let touch = allTouches.first,
              touch.phase == .began,
              let target = touch.view else {
            return
        }

        // check if the view type should be ignored
        let shouldCapture = options.delegate?.shouldCaptureTap(onView: target) ?? true
        guard shouldCapture else {
            return
        }

        guard options.ignoredViewTypes.first(where: { type(of: target) == $0 }) == nil else {
            return
        }

        // get view name
        let accessibilityIdentifier = target.accessibilityIdentifier
        let targetClass = type(of: target)

        let viewName = accessibilityIdentifier ?? String(describing: targetClass)

        var attributes: [String: AttributeValue] = [
            SpanEventSemantics.Tap.keyViewName: .string(viewName),
            SpanEventSemantics.keyEmbraceType: .string(SpanType.tap.rawValue)
        ]

        // get coordinates
        if shouldRecordCoordinates(from: target) {
            let point = touch.location(in: target.window)
            attributes[SpanEventSemantics.Tap.keyCoordinates] = .string(point.toString())
            Embrace.logger.trace("Captured tap at \(point) on: \(viewName)")
        } else {
            Embrace.logger.trace("Captured tap with no coordinates on: \(viewName)")
        }

        // create span event
        let event = RecordingSpanEvent(
            name: SpanEventSemantics.Tap.name,
            timestamp: Date(),
            attributes: attributes
        )
        add(event: event)
    }

    func shouldRecordCoordinates(from target: UIView) -> Bool {

        let shouldCapture =
            options.delegate?.shouldCaptureTapCoordinates(onView: target) ??
            options.captureTapCoordinates
        guard shouldCapture else {
            return false
        }

        guard let keyboardViewClass = NSClassFromString("UIKeyboardLayout"),
              let keyboardWindowClass = NSClassFromString("UIRemoteKeyboardWindow")
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
        try swizzleInstanceMethod { originalImplementation in { [weak self] uiWindow, uiEvent -> Void in
                self?.onEvent?(uiEvent)
                originalImplementation(uiWindow, UIWindowSendEventSwizzler.selector, uiEvent)
            }
        }
    }
}

#endif
