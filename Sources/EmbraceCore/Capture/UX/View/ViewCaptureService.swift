//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit
    import SwiftUI
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceSemantics
        import EmbraceCaptureService
        import EmbraceCommonInternal
        import EmbraceConfigInternal
        import EmbraceConfiguration
    #endif

    /// Service that generates OpenTelemetry spans to instrument `UIViewController` load time and visibility.
    public final class ViewCaptureService: CaptureService, UIViewControllerHandlerDataSource {
        /// The options used to configure this service.
        public let options: ViewCaptureService.Options
        private let handler: UIViewControllerHandler
        private let swizzler: EmbraceSwizzler
        private let swizzlerCache: ViewCaptureServiceSwizzlerCache
        private let bundlePath: String
        private let lock: NSLocking

        var serviceState: CaptureServiceState {
            state.load()
        }

        var instrumentVisibility: Bool {
            return options.instrumentVisibility
        }

        var instrumentFirstRender: Bool {
            return options.instrumentFirstRender && Embrace.client?.config.isUiLoadInstrumentationEnabled == true
        }

        /// Whether the screen-load vital is captured. It also needs ``instrumentFirstRender``.
        /// Off until it is wired to remote config.
        var instrumentScreenLoad: Bool {
            return false
        }

        /// Taps for the screen-load vital, from the `TapCaptureService` if there is one. Set by
        /// `CaptureServices` before install.
        var screenLoadTapSource: ScreenLoadTapSource?

        var blockList = EmbraceMutex(ViewControllerBlockList())

        /// Creates a new `ViewCaptureService` with the given options.
        /// - Parameter options: The options used to configure the service.
        public convenience init(options: ViewCaptureService.Options = ViewCaptureService.Options()) {
            self.init(options: options, lock: NSLock())
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
            self.blockList.safeValue = options.viewControllerBlockList

            super.init()

            updateBlockList(config: Embrace.client?.config.configurable)
        }

        public override func onConfigUpdated(_ config: EmbraceConfigurable) {
            updateBlockList(config: config)
        }

        private func updateBlockList(config: EmbraceConfigurable?) {
            if let config {
                var names = config.viewControllerClassNameBlocklist

                // if no vc names were provided, use the user-provided ones
                if names.isEmpty {
                    names = options.viewControllerBlockList.names
                }

                blockList.safeValue = ViewControllerBlockList(
                    names: names,
                    blockHostingControllers: !config.uiInstrumentationCaptureHostingControllers
                )
            } else {
                blockList.safeValue = options.viewControllerBlockList
            }
        }

        func isViewControllerBlocked(_ vc: UIViewController) -> Bool {
            return blockList.safeValue.isBlocked(viewController: vc)
        }

        /// Owns the screen-navigation timeline. Built on the first start that passes the gate and kept
        /// for the service's lifetime, so a restart reuses the registered recorder.
        ///
        /// Hosted here because this service already owns the appearance instrumentation the timeline
        /// is built from, so there is no second swizzler or block list.
        var screenTracker: ScreenTrackingHandler?

        func onViewBecameInteractive(_ vc: UIViewController) {
            handler.onViewBecameInteractive(vc)
        }

        func parentSpan(for vc: UIViewController) -> EmbraceSpan? {
            return handler.parentSpan(for: vc)
        }

        override public func onInstall() {
            lock.lock()
            defer {
                lock.unlock()
            }

            guard options.instrumentVisibility || options.instrumentFirstRender else {
                return
            }

            handler.dataSource = self

            if instrumentFirstRender {
                instrumentInitWithCoder()
                instrumentInitWithNibAndBundle()
            }

            if instrumentVisibility || instrumentFirstRender {
                instrumentRender(of: UIViewController.self)
            }

            if instrumentVisibility {
                instrumentViewDidDisappear(of: UIViewController.self)
            }
        }

        override public func onStart() {
            lock.lock()
            defer {
                lock.unlock()
            }

            startScreenTrackingIfEnabled()

            // Disabled means no tracker, observers or tap hook at all, not just no spans.
            if handler.isScreenLoadEnabled {
                handler.screenLoadHandler.start(tapSource: screenLoadTapSource)
            }
        }

        override public func onStop() {
            lock.lock()
            defer {
                lock.unlock()
            }

            stopScreenTracking()
            handler.screenLoadHandler.stop()
        }
    }

    extension ViewCaptureService {

        fileprivate func instrumentRender(of viewControllerType: UIViewController.Type) {
            instrumentViewDidLoad(of: viewControllerType)
            instrumentViewWillAppear(of: viewControllerType)
            instrumentViewIsAppearing(of: viewControllerType)
            instrumentViewDidAppear(of: viewControllerType)
        }

        fileprivate func instrumentViewDidLoad(of viewControllerType: UIViewController.Type) {
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

        fileprivate func instrumentViewWillAppear(of viewControllerType: UIViewController.Type) {
            let selector = #selector(UIViewController.viewWillAppear(_:))
            do {
                try swizzler.swizzleDeclaredInstanceMethod(
                    in: viewControllerType,
                    selector: selector,
                    implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                    blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
                ) { originalImplementation in
                    { viewController, animated in
                        // Above the span-creation latch on purpose: `…SpanCreated` is set on first
                        // appearance and never reset, and `emb_instrumentation_state` is absent when
                        // render instrumentation is off. The timeline needs every appearance.
                        self.onViewControllerAppearance(viewController, phase: .willAppear, at: Date())

                        // If by this time (`viewWillAppear` being called) there's no `emb_instrumentation_state` associated
                        // to the viewController, then we don't swizzle as the "instrument render" feature might be disabled.
                        if let state = viewController.emb_instrumentation_state {
                            // If the state was already fulfilled, then call the original implementation.
                            if state.viewWillAppearSpanCreated {
                                originalImplementation(viewController, selector, animated)
                                return
                            }

                            // Start and end a `viewWillAppear` span.
                            // Before iOS 17, `onViewWillAppearEnd` is also screen load's navigation end, so
                            // that relies on this latch: screen load is only on when first render is.
                            self.handler.onViewWillAppearStart(viewController)
                            originalImplementation(viewController, selector, animated)
                            self.handler.onViewWillAppearEnd(viewController)

                            // Start a `viewIsAppearing` span to measure the animation times.
                            // Note: the span doesn't use the `viewIsAppearing` swizzle below, which only
                            // exists from iOS 17 and only feeds screen load.
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

        /// Screen load's navigation end on iOS 17+. Unlike the other appearance swizzles, it creates no
        /// view spans.
        fileprivate func instrumentViewIsAppearing(of viewControllerType: UIViewController.Type) {
            guard ViewControllerScreenLoadHandler.isViewIsAppearingAvailable else {
                return
            }

            let selector = #selector(UIViewController.viewIsAppearing(_:))
            do {
                try swizzler.swizzleDeclaredInstanceMethod(
                    in: viewControllerType,
                    selector: selector,
                    implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                    blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
                ) { originalImplementation in
                    { viewController, animated in
                        // Bracketed so the handler can tell when the outermost implementation ends: an
                        // override that calls `super` runs the base class's swizzle inside its own.
                        self.handler.onViewIsAppearingCallbackStart(viewController)
                        originalImplementation(viewController, selector, animated)
                        self.handler.onViewIsAppearingCallbackEnd(viewController)
                    }
                }
            } catch let exception {
                Embrace.logger.error("Error swizzling viewIsAppearing: \(exception.localizedDescription)")
            }
        }

        fileprivate func instrumentViewDidAppear(of viewControllerType: UIViewController.Type) {
            let selector = #selector(UIViewController.viewDidAppear(_:))
            do {
                try swizzler.swizzleDeclaredInstanceMethod(
                    in: viewControllerType,
                    selector: selector,
                    implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                    blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
                ) { originalImplementation in
                    { viewController, animated in
                        // See `instrumentViewWillAppear`: above the span-creation latch on purpose.
                        self.onViewControllerAppearance(viewController, phase: .didAppear, at: Date())

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

        fileprivate func instrumentViewDidDisappear(of viewControllerType: UIViewController.Type) {
            let selector = #selector(UIViewController.viewDidDisappear(_:))
            do {
                try swizzler.swizzleDeclaredInstanceMethod(
                    in: viewControllerType,
                    selector: selector,
                    implementationType: (@convention(c) (UIViewController, Selector, Bool) -> Void).self,
                    blockImplementationType: (@convention(block) (UIViewController, Bool) -> Void).self
                ) { originalImplementation in
                    { viewController, animated in
                        self.onViewControllerAppearance(viewController, phase: .didDisappear, at: Date())
                        self.handler.onViewDidDisappear(viewController)
                        originalImplementation(viewController, selector, animated)
                    }
                }
            } catch let exception {
                Embrace.logger.error("Error swizzling viewDidDisappear: \(exception.localizedDescription)")
            }
        }

        fileprivate func instrumentInitWithCoder() {
            let selector = #selector(UIViewController.init(coder:))
            do {
                try swizzler.swizzleDeclaredInstanceMethod(
                    in: UIViewController.self,
                    selector: selector,
                    implementationType: (@convention(c) (UIViewController, Selector, NSCoder) -> UIViewController?)
                        .self,
                    blockImplementationType: (@convention(block) (UIViewController, NSCoder) -> UIViewController?).self
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

        fileprivate func instrumentInitWithNibAndBundle() {
            let selector = #selector(UIViewController.init(nibName:bundle:))
            do {
                try swizzler.swizzleDeclaredInstanceMethod(
                    in: UIViewController.self,
                    selector: selector,
                    implementationType: (@convention(c) (UIViewController, Selector, String?, Bundle?) ->
                        UIViewController).self,
                    blockImplementationType: (@convention(block) (UIViewController, String?, Bundle?) ->
                        UIViewController).self
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
                        return originalImplementation(viewController, selector, nibName, bundle)
                    }
                }
            } catch let exception {
                Embrace.logger.error("Error swizzling init(nibName:bundle:): \(exception.localizedDescription)")
            }
        }
    }
#endif
