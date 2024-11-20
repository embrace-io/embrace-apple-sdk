//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)
import UIKit
import SwiftUI
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import OpenTelemetryApi

/// Service that generates OpenTelemetry spans for `UIViewControllers`.
@objc(EMBViewCaptureService)
public final class ViewCaptureService: CaptureService, UIViewControllerHandlerDataSource {

    public let options: ViewCaptureService.Options
    private var lock: NSLocking
    private var swizzlers: [any Swizzlable] = []
    private var handler: UIViewControllerHandler

    var instrumentVisibility: Bool {
        return options.instrumentVisibility
    }

    var instrumentFirstRender: Bool {
        return options.instrumentFirstRender
    }

    @objc public convenience init(options: ViewCaptureService.Options) {
        self.init(options: options, lock: NSLock())
    }

    public convenience override init() {
        self.init(lock: NSLock())
    }

    init(
        options: ViewCaptureService.Options = ViewCaptureService.Options(),
        lock: NSLocking,
        handler: UIViewControllerHandler = UIViewControllerHandler()
    ) {
        self.options = options
        self.lock = lock
        self.handler = handler
    }

    func onViewBecameInteractive(_ vc: UIViewController) {
        handler.onViewBecameInteractive(vc)
    }

    func parentSpan(for vc: UIViewController) -> Span? {
        return handler.parentSpan(for: vc)
    }

    override public func onInstall() {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard state == .uninstalled else {
            return
        }

        guard options.instrumentVisibility || options.instrumentFirstRender else {
            return
        }

        handler.dataSource = self
        initializeSwizzlers()

        swizzlers.forEach {
            do {
                try $0.install()
            } catch let exception {
                Embrace.logger.error("Capture service couldn't be installed: \(exception.localizedDescription)")
            }
        }
    }

    private func initializeSwizzlers() {
        swizzlers.append(UIViewControllerViewDidLoadSwizzler(handler: handler))
        swizzlers.append(UIViewControllerViewWillAppearSwizzler(handler: handler))
        swizzlers.append(UIViewControllerViewDidAppearSwizzler(handler: handler))
        swizzlers.append(UIViewControllerViewDidDisappearSwizzler(handler: handler))
    }
}

class UIViewControllerViewDidLoadSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIViewController, Selector) -> Void
    typealias BlockImplementationType = @convention(block) (UIViewController) -> Void
    static var selector: Selector = #selector(UIViewController.viewDidLoad)
    var baseClass: AnyClass = UIViewController.self

    private let handler: UIViewControllerHandler

    init(handler: UIViewControllerHandler) {
        self.handler = handler
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] viewController -> Void in
                self?.handler.onViewDidLoadStart(viewController)
                originalImplementation(viewController, Self.selector)
                self?.handler.onViewDidLoadEnd(viewController)
            }
        }
    }
}

class UIViewControllerViewWillAppearSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIViewController, Selector, Bool) -> Void
    typealias BlockImplementationType = @convention(block) (UIViewController, Bool) -> Void
    static var selector: Selector = #selector(UIViewController.viewWillAppear(_:))
    var baseClass: AnyClass = UIViewController.self

    private let handler: UIViewControllerHandler

    init(handler: UIViewControllerHandler) {
        self.handler = handler
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] viewController, animated -> Void in
                self?.handler.onViewWillAppearStart(viewController)
                originalImplementation(viewController, Self.selector, animated)
                self?.handler.onViewWillAppearEnd(viewController)
            }
        }
    }
}

class UIViewControllerViewDidAppearSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIViewController, Selector, Bool) -> Void
    typealias BlockImplementationType = @convention(block) (UIViewController, Bool) -> Void
    static var selector: Selector = #selector(UIViewController.viewDidAppear(_:))
    var baseClass: AnyClass = UIViewController.self

    private let handler: UIViewControllerHandler

    init(handler: UIViewControllerHandler) {
        self.handler = handler
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] viewController, animated -> Void in
                self?.handler.onViewDidAppearStart(viewController)
                originalImplementation(viewController, Self.selector, animated)
                self?.handler.onViewDidAppearEnd(viewController)
            }
        }
    }
}

class UIViewControllerViewDidDisappearSwizzler: Swizzlable {
    typealias ImplementationType = @convention(c) (UIViewController, Selector, Bool) -> Void
    typealias BlockImplementationType = @convention(block) (UIViewController, Bool) -> Void
    static var selector: Selector = #selector(UIViewController.viewDidDisappear(_:))
    var baseClass: AnyClass = UIViewController.self

    private let handler: UIViewControllerHandler

    init(handler: UIViewControllerHandler) {
        self.handler = handler
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak self] viewController, animated -> Void in
                self?.handler.onViewDidDisappear(viewController)
                originalImplementation(viewController, Self.selector, animated)
            }
        }
    }
}

#endif
