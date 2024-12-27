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
import Foundation

@objc(EMBViewCaptureService)
public final class ViewCaptureService: CaptureService, UIViewControllerHandlerDataSource {
    public let options: ViewCaptureService.Options
    private let handler: UIViewControllerHandler
    private let swizzler: EmbraceSwizzler
    private let swizzlerCache: ViewCaptureServiceSwizzlerCache
    private let bundlePath: String
    private let lock: NSLocking

    var instrumentVisibility: Bool {
        return options.instrumentVisibility
    }

    var instrumentFirstRender: Bool {
        return options.instrumentFirstRender
    }

    var instrumentationFirstRenderMode: ViewCaptureService.InstrumentFirstRenderMode {
        return options.instrumentFirstRenderMode
    }

    @objc public convenience init(options: ViewCaptureService.Options) {
        self.init(options: options, lock: NSLock())
    }

    public convenience override init() {
        self.init(lock: NSLock())
    }

    init(
        options: ViewCaptureService.Options = ViewCaptureService.Options(),
        handler: UIViewControllerHandler = UIViewControllerHandler(),
        swizzler: EmbraceSwizzler = .init(),
        swizzlerCache: ViewCaptureServiceSwizzlerCache = .withDefaults(),
        bundle: Bundle = .main,
        lock: NSLocking
    ) {
        self.options = options
        self.handler = handler
        self.swizzler = EmbraceSwizzler()
        self.swizzlerCache = swizzlerCache
        self.bundlePath = bundle.bundlePath
        self.lock = lock
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

        if instrumentFirstRender {
            switch instrumentationFirstRenderMode {
            case .automatic:
                instrumentInitWithCoder()
                instrumentInitWithNibAndBundle()
            case .manual(let viewControllers):
                for viewController in viewControllers {
                    instrumentRender(of: viewController)
                }
            default: break
            }
        }

        if instrumentVisibility || instrumentFirstRender {
            instrumentRender(of: UIViewController.self)
        }

        if instrumentVisibility {
            instrumentViewDidDisappear(of: UIViewController.self)
        }
    }
}

private extension ViewCaptureService {

    func instrumentRender(of viewControllerType: UIViewController.Type) {
        instrumentViewDidLoad(of: viewControllerType)
        instrumentViewWillAppear(of: viewControllerType)
        instrumentViewDidAppear(of: viewControllerType)
    }

    func instrumentViewDidLoad(of viewControllerType: UIViewController.Type) {
        let selector = #selector(UIViewController.viewDidLoad)
        do {
            try swizzler.swizzleDeclaredInstanceMethod(
                in: viewControllerType,
                selector: selector,
                implementationType: (@convention(c) (UIViewController, Selector) -> Void).self,
                blockImplementationType: (@convention(block) (UIViewController) -> Void).self
            ) { originalImplementation in
                { viewController in
                    // If the state was already fulfilled, then call the original implementation.
                    if let state = viewController.emb_instrumentation_state, state.viewDidLoadSpanCreated {
                        originalImplementation(viewController, selector)
                        return
                    }

                    // Start and end a `viewDidLoad` span
                    self.handler.onViewDidLoadStart(viewController)
                    originalImplementation(viewController, selector)
                    self.handler.onViewDidLoadEnd(viewController)
                }
            }
        } catch let exception {
            Embrace.logger.error("Error swizzling viewDidLoad: \(exception.localizedDescription)")
        }
    }

    func instrumentViewWillAppear(of viewControllerType: UIViewController.Type) {
        let selector = #selector(UIViewController.viewWillAppear(_:))
        do {
            try swizzler.swizzleDeclaredInstanceMethod(
                in: viewControllerType,
                selector: selector,
                implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
            ) { originalImplementation in
                { viewController, animated in
                    // If by this time (`viewWillAppear` being called) there's no `emb_instrumentation_state` associated
                    // to the viewController, then we don't swizzle as the "instrument render" feature might be disabled.
                    if let state = viewController.emb_instrumentation_state {
                        // If the state was already fulfilled, then call the original implementation.
                        if state.viewWillAppearSpanCreated {
                            originalImplementation(viewController, selector, animated)
                            return
                        }

                        // Start and end a `viewWillAppear` span
                        self.handler.onViewWillAppearStart(viewController)
                        originalImplementation(viewController, selector, animated)
                        self.handler.onViewWillAppearEnd(viewController)

                        // Start a `viewIsAppearing` span to measure the animation times.
                        // Note: we're not swizzling `viewIsAppearing` as:
                        // 1. Most people doesn't override it.
                        // 2. It's only available for iOS 15 and up.
                        self.handler.onViewIsAppearingStart(viewController)
                    } else {
                        // Fall back to the original implementation
                        originalImplementation(viewController, selector, animated)
                    }
                }
            }
        } catch let exception {
            Embrace.logger.error("Error swizzling viewWillAppear: \(exception.localizedDescription)")
        }
    }

    func instrumentViewDidAppear(of viewControllerType: UIViewController.Type) {
        let selector = #selector(UIViewController.viewDidAppear(_:))
        do {
            try swizzler.swizzleDeclaredInstanceMethod(
                in: viewControllerType,
                selector: selector,
                implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
            ) { originalImplementation in
                { viewController, animated in
                    // If the state was already fulfilled, then call the original implementation.
                    if let state = viewController.emb_instrumentation_state, state.viewDidAppearSpanCreated {
                        originalImplementation(viewController, selector, animated)
                        return
                    }

                    // If we started a `viewIsAppearing` span, we ensure we end it.
                    // This ensures that spans measuring animation times are properly closed,
                    if let state = viewController.emb_instrumentation_state, state.viewIsAppearingSpanCreated {
                        self.handler.onViewIsAppearingEnd(viewController)
                    }

                    // Start and end a `viewDidAppear` span
                    self.handler.onViewDidAppearStart(viewController)
                    originalImplementation(viewController, selector, animated)
                    self.handler.onViewDidAppearEnd(viewController)
                }
            }
        } catch let exception {
            Embrace.logger.error("Error swizzling viewDidAppear: \(exception.localizedDescription)")
        }
    }

    func instrumentViewDidDisappear(of viewControllerType: UIViewController.Type) {
        let selector = #selector(UIViewController.viewDidDisappear(_:))
        do {
            try swizzler.swizzleDeclaredInstanceMethod(
                in: viewControllerType,
                selector: selector,
                implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
            ) { originalImplementation in
                { viewController, animated in
                    self.handler.onViewDidDisappear(viewController)
                    originalImplementation(viewController, selector, animated)
                }
            }
        } catch let exception {
            Embrace.logger.error("Error swizzling viewDidDisappear: \(exception.localizedDescription)")
        }
    }

    func instrumentInitWithCoder() {
        let selector = #selector(UIViewController.init(coder:))
        do {
            try swizzler.swizzleDeclaredInstanceMethod(
                in: UIViewController.self,
                selector: selector,
                implementationType: (
                    @convention(c) (UIViewController, Selector, NSCoder) -> UIViewController?
                ).self,
                blockImplementationType: (
                    @convention(block) (UIViewController, NSCoder) -> UIViewController?
                ).self
            ) { originalImplementation in
                { viewController, coder in
                    // Get the class and bundle path of the view controller being initialized and check
                    // if the view controller belongs to the main bundle (this excludes, for eaxmple, UIKit classes)
                    let viewControllerClass = type(of: viewController)
                    let viewControllerBundlePath = Bundle(for: viewControllerClass).bundlePath
                    guard viewControllerBundlePath.contains(self.bundlePath) else {
                        return originalImplementation(viewController, selector, coder)
                    }

                    // If the view controller hasn't been swizzled yet, instrument its lifecycle
                    if !self.swizzlerCache.wasViewControllerSwizzled(withType: viewControllerClass) {
                        self.instrumentRender(of: viewControllerClass)
                        self.swizzlerCache.addNewSwizzled(viewControllerType: viewControllerClass)
                    }

                    // return the result of the original implementation
                    return originalImplementation(viewController, selector, coder)
                }
            }
        } catch let exception {
            Embrace.logger.error("Error swizzling init(coder:): \(exception.localizedDescription)")
        }
    }

    func instrumentInitWithNibAndBundle() {
        let selector = #selector(UIViewController.init(nibName:bundle:))
        do {
            try swizzler.swizzleDeclaredInstanceMethod(
                in: UIViewController.self,
                selector: selector,
                implementationType: (
                    @convention(c) (UIViewController, Selector, String?, Bundle?) -> UIViewController
                ).self,
                blockImplementationType: (
                    @convention(block) (UIViewController, String?, Bundle?) -> UIViewController
                ).self
            ) { originalImplementation in
                { viewController, nibName, bundle in
                    // Get the class and bundle path of the view controller being initialized and check
                    // if the view controller belongs to the main bundle (this excludes, for eaxmple, UIKit classes)
                    let viewControllerClass = type(of: viewController)
                    let viewControllerBundlePath = Bundle(for: viewControllerClass).bundlePath
                    guard viewControllerBundlePath.contains(self.bundlePath) else {
                        return originalImplementation(viewController, selector, nibName, bundle)
                    }

                    // If the view controller hasn't been swizzled yet, instrument its lifecycle
                    if !self.swizzlerCache.wasViewControllerSwizzled(withType: viewControllerClass) {
                        self.instrumentRender(of: viewControllerClass)
                        self.swizzlerCache.addNewSwizzled(viewControllerType: viewControllerClass)
                    }

                    // return the result of the original implementation
                    return originalImplementation(viewController, selector, nibName, bundle)                }
            }
        } catch let exception {
            Embrace.logger.error("Error swizzling init(nibName:bundle:): \(exception.localizedDescription)")
        }
    }
}
#endif
