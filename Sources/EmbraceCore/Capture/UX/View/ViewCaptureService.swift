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

        /// Owns the screen-navigation timeline when enabled, `nil` when not.
        ///
        /// Hosted here because this service already owns the appearance instrumentation the timeline
        /// is built from, so there is no second swizzler or block list. `nil` means events are never
        /// constructed at all, rather than built and discarded.
        internal var navigationTracker: ScreenNavigationTracker?

        /// Keeps this service published as the reporter for screens declared in SwiftUI. Releasing
        /// it withdraws, so the registry cannot outlive the service that filled it.
        private var manualScreenRegistration: ManualScreenRegistry.Registration?

        /// Feeds the screen-navigation timeline from a raw appearance callback.
        ///
        /// Called straight from the swizzle on the callback's own thread, so the broker stays on the
        /// main queue and load times keep the OS timestamp.
        ///
        /// Checks `serviceState` itself: the tap runs above the only upstream check, so without this
        /// a stopped SDK would keep feeding the timeline.
        fileprivate func onViewControllerAppearance(
            _ vc: UIViewController,
            phase: ScreenAppearancePhase,
            at time: Date
        ) {
            guard serviceState == .active else {
                return
            }

            navigationTracker?.onAppearance(vc, phase: phase, at: time)
        }

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

            startScreenNavigationTrackingIfEnabled()
        }

        override public func onStop() {
            lock.lock()
            defer {
                lock.unlock()
            }

            // Withdrawn explicitly rather than left to deallocation, so when this service stops
            // being the published reporter does not depend on when ARC drops the last reference.
            // The tracker is deliberately kept — see `startScreenNavigationTrackingIfEnabled`.
            manualScreenRegistration = nil
        }

        /// Whether the screen-navigation timeline should run. Split from the wiring below so the
        /// combination is testable without an SDK instance.
        ///
        /// ``instrumentVisibility`` is required mechanically, not philosophically: it alone installs
        /// the `viewDidDisappear` swizzle, and without those pause events screens are never removed
        /// from the visible set — backdating stops from the second screen on, giving a timeline that
        /// looks complete and is systematically late. It is also sufficient, since it installs all
        /// three appearance swizzles and the taps sit above their span bookkeeping.
        static func shouldTrackScreenNavigation(
            instrumentVisibility: Bool,
            config: EmbraceConfigurable?
        ) -> Bool {
            guard let config else {
                return false
            }

            return instrumentVisibility
                && config.isStateCaptureEnabled
                && config.isScreenTrackingEnabled
        }

        /// Evaluates the gate at start, never on a config refresh.
        ///
        /// ``StateCaptureCoordinator`` has no `unregister`, so a recorder added later would start
        /// its timeline mid-part with an `initial_value` for a screen the user had already left, and
        /// a gate turning *off* could not be honoured until relaunch anyway. Config is read from
        /// cache during setup, so this only costs the first launch after install.
        private func startScreenNavigationTrackingIfEnabled() {
            guard let client = Embrace.client,
                Self.shouldTrackScreenNavigation(
                    instrumentVisibility: instrumentVisibility,
                    config: client.config.configurable
                )
            else {
                return
            }

            // Built at most once. `StateCaptureCoordinator` has no `unregister`, so a second tracker
            // would mean a second recorder and two `emb-state-screen-automatic` spans in every
            // later part.
            if navigationTracker == nil {
                let reporter = ScreenStateReporter(otel: otel)

                let tracker = ScreenNavigationTracker(reporter: reporter) { [weak self] vc in
                    // No service means no block list to consult; treat that as blocked rather than
                    // capturing screens this service would have excluded.
                    self?.isViewControllerBlocked(vc) ?? true
                }
                navigationTracker = tracker

                client.stateCoordinator.register(
                    reporter.recorder,
                    sessionSpan: client.sessionController.currentSessionSpan
                )

                // Routed through this service rather than handing the lifecycle the tracker
                // directly, so app-state transitions get the same `serviceState` check as
                // appearance callbacks. Held weakly by the lifecycle; this service owns the
                // tracker's lifetime.
                client.sessionLifecycle.setAppStateObserver(self)
            }

            // Published on *every* start, unlike the tracker: `onStop` withdraws, so a restart
            // would otherwise keep UIKit screens working while silently dropping every SwiftUI one.
            // Publishing only once the gate has passed is what makes the modifier a no-op when the
            // feature is off — there is nothing to report to.
            manualScreenRegistration = ManualScreenRegistry.publish(self)
        }
    }

    extension ViewCaptureService: AppStateObserver {

        func appWillBackground(at time: Date) {
            guard serviceState == .active else { return }
            navigationTracker?.appWillBackground(at: time)
        }

        func appDidForeground(at time: Date) {
            guard serviceState == .active else { return }
            navigationTracker?.appDidForeground(at: time)
        }
    }

    extension ViewCaptureService: ManualScreenReporting {

        func onManualScreenAppear(
            id: ObjectIdentifier,
            name: String,
            attributes: EmbraceAttributes,
            at time: Date
        ) {
            guard serviceState == .active else { return }
            navigationTracker?.onManualScreenAppear(id: id, name: name, attributes: attributes, at: time)
        }

        func onManualScreenDisappear(id: ObjectIdentifier, name: String, at time: Date) {
            guard serviceState == .active else { return }
            navigationTracker?.onManualScreenDisappear(id: id, name: name, at: time)
        }
    }

    extension ViewCaptureService {

        fileprivate func instrumentRender(of viewControllerType: UIViewController.Type) {
            instrumentViewDidLoad(of: viewControllerType)
            instrumentViewWillAppear(of: viewControllerType)
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
                        self.onViewControllerAppearance(viewController, phase: .willAppear, at: Date())

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
