//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceConfiguration
    #endif

    /// Which appearance callback a view controller is reporting.
    enum ScreenAppearancePhase {
        case willAppear
        case didAppear
        case didDisappear
    }

    /// Screen tracking's UIKit side: which view controllers count as screens, and the wiring that
    /// starts and stops the ``ScreenTrackingHandler``.
    extension ViewCaptureService {

        /// Skipped: containers appear alongside the content they present, which would both put
        /// "UINavigationController" in the timeline and keep two screens visible at once —
        /// suppressing load-time backdating for the real one.
        private static let containerClasses: [UIViewController.Type] = [
            UINavigationController.self,
            UITabBarController.self,
            UISplitViewController.self,
            UIPageViewController.self
        ]

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
        /// ``StateController`` has no `unregister`, so a recorder added later would start its
        /// timeline mid-part with an `initial_value` for a screen the user had already left, and a
        /// gate turning *off* could not be honoured until relaunch anyway. Config is read from cache
        /// during setup, so this only costs the first launch after install.
        func startScreenTrackingIfEnabled() {
            guard let client = Embrace.client,
                Self.shouldTrackScreenNavigation(
                    instrumentVisibility: instrumentVisibility,
                    config: client.config.configurable
                )
            else {
                return
            }

            // Built at most once. `StateController` has no `unregister`, so a second handler would
            // mean a second recorder and two `emb-state-screen-automatic` spans in every later part.
            let handler: ScreenTrackingHandler
            if let screenTracker {
                handler = screenTracker
            } else {
                handler = ScreenTrackingHandler(otel: otel)
                screenTracker = handler
                client.stateController.register(handler.recorder)
            }

            // Connected on *every* start, unlike the handler: `onStop` disconnects both, which is what
            // stops a stopped service from feeding the timeline through them.
            client.sessionLifecycle.setAppStateObserver(handler)
            ScreenTrackingHandler.makeCurrent(handler)
        }

        func stopScreenTracking() {
            guard let screenTracker else {
                return
            }
            Embrace.client?.sessionLifecycle.setAppStateObserver(nil)
            ScreenTrackingHandler.resignCurrent(screenTracker)
        }

        /// Feeds the screen-navigation timeline from a raw appearance callback.
        ///
        /// Called straight from the swizzle on the callback's own thread, so the timeline stays on
        /// the main queue and load times keep the OS timestamp.
        ///
        /// Checks `serviceState` itself: the tap runs above the only upstream check, so without this
        /// a stopped SDK would keep feeding the timeline.
        func onViewControllerAppearance(_ vc: UIViewController, phase: ScreenAppearancePhase, at time: Date) {
            guard serviceState == .active, let screenTracker else {
                return
            }

            let id = ObjectIdentifier(vc)
            switch phase {
            case .willAppear:
                guard shouldTrackScreen(vc) else { return }
                screenTracker.screenWillAppear(id, name: vc.emb_viewName, at: time)

            case .didAppear:
                guard shouldTrackScreen(vc) else { return }
                screenTracker.screenDidAppear(id, name: vc.emb_viewName, at: time)

            case .didDisappear:
                // Forwarded unconditionally: a pause emits nothing and only clears bookkeeping, so it
                // stays correct even for a controller the filter refused.
                screenTracker.screenDidDisappear(id, at: time)
            }
        }

        /// Decided by what the controller *is*, never by the screen name it would ship — a name that
        /// collides with one of the SDK's own values is kept apart by ``Screen/isSystemValue``
        /// instead. The anonymous-host test below is on the controller's *class*, which is a
        /// different question.
        func shouldTrackScreen(_ vc: UIViewController) -> Bool {
            // A controller the customer has already opted out of stays out of both streams.
            guard vc.emb_shouldCaptureView, !isViewControllerBlocked(vc) else {
                return false
            }

            guard !Self.isAnonymousHostingController(vc) else {
                return false
            }

            // `isKind(of:)` rather than `isMember(of:)`: custom container subclasses are common, and
            // a `MyNavigationController: UINavigationController` is just as much a container.
            return !Self.containerClasses.contains { vc.isKind(of: $0) }
        }

        /// A SwiftUI host whose resolved name describes a view tree rather than a screen.
        ///
        /// Decided here rather than deferring to the view instrumentation's block list, because the
        /// two are answering different questions. `uiInstrumentationCaptureHostingControllers`
        /// governs whether SwiftUI hosts get *view* spans — how long something took to render. The
        /// timeline asks what screen the user is on, and a bare host answers that with
        /// `UIHostingController<ModifiedContent<Text, _PaddingLayout>>`. Letting that flag decide
        /// would put such names in the timeline the moment it was turned on. SwiftUI screens are
        /// named with the `.embraceScreen` modifier.
        ///
        /// Naming it is an unconditional opt-in — otherwise the generic test would run against the
        /// developer's own string and reject `"Cart <checkout v2>"` for a character they meant
        /// nothing by.
        ///
        /// Failing that, the test is on the *class* name, since that is what produces the soup.
        /// `CheckoutHostingController` is kept; a generic subclass like `ScreenHost<CheckoutView>`
        /// is not, and its way in is the customization protocol.
        ///
        /// Deliberately does not walk up to parents the way the block list does. A child view
        /// controller presented inside SwiftUI has a real class name of its own; only the host is
        /// anonymous. Note the block list still gets the first say, so under the default config
        /// (hosts blocked) none of this is reached.
        private static func isAnonymousHostingController(_ vc: UIViewController) -> Bool {
            guard vc is EmbraceIdentifiableHostingController else {
                return false
            }

            if let customized = vc as? EmbraceViewControllerCustomization,
                customized.nameForViewControllerInEmbrace != nil
            {
                return false
            }

            return vc.className.contains("<")
        }
    }
#endif
