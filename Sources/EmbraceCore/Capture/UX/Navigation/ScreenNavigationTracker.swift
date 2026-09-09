//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceSemantics
    #endif

    /// Which appearance callback a view controller is reporting.
    ///
    /// Kept separate from ``NavigationEvent/Kind`` so the view-instrumentation side can forward raw
    /// UIKit lifecycle without owning any part of the navigation model.
    enum ScreenAppearancePhase {
        case willAppear
        case didAppear
        case didDisappear
    }

    /// Turns view controller appearance callbacks into the navigation timeline.
    ///
    /// Sits between the existing view instrumentation and ``NavigationEventBroker``: it decides
    /// *which* controllers count as screens and what they are called, and the broker decides what
    /// the resulting timeline looks like.
    ///
    /// ## Threading
    /// Appearance callbacks arrive on the main thread and are forwarded straight through, because
    /// the broker's serialization contract is the main queue. Everything here is main-only; nothing
    /// is dispatched, so the load time a transition is attributed to stays the timestamp of the
    /// original callback.
    final class ScreenNavigationTracker {

        /// Container controllers are skipped: they appear alongside the content they present, so
        /// letting them through would put "UINavigationController" in the timeline and, worse, make
        /// two screens visible at once — which suppresses load-time backdating for the real screen.
        private static let containerClasses: [UIViewController.Type] = [
            UINavigationController.self,
            UITabBarController.self,
            UISplitViewController.self,
            UIPageViewController.self
        ]

        private let broker: NavigationEventBroker
        private let reporter: ScreenStateReporter

        /// Whether this controller is excluded by the customer's or the config's block list.
        private let isBlocked: (UIViewController) -> Bool

        init(
            reporter: ScreenStateReporter,
            isBlocked: @escaping (UIViewController) -> Bool
        ) {
            self.reporter = reporter
            self.isBlocked = isBlocked
            self.broker = NavigationEventBroker(onScreenLoad: reporter.onScreenLoad)
        }

        // MARK: - Input

        func onAppearance(_ vc: UIViewController, phase: ScreenAppearancePhase, at time: Date) {
            let componentId = ObjectIdentifier(vc)
            let name = vc.emb_viewName

            switch phase {
            case .willAppear:
                guard shouldTrack(vc) else { return }
                broker.handle(.started(componentId, name: name, at: time))

            case .didAppear:
                guard shouldTrack(vc) else { return }
                broker.handle(.resumed(componentId, name: name, at: time))

            case .didDisappear:
                broker.handle(.paused(componentId, name: name, at: time))
            }
        }

        // MARK: - Filtering

        private func shouldTrack(_ vc: UIViewController) -> Bool {
            // Reuses the view instrumentation's existing exclusions rather than inventing a second
            // set, so a controller a customer has already opted out of stays out of both streams.
            guard vc.emb_shouldCaptureView, !isBlocked(vc) else {
                return false
            }

            guard !Self.isAnonymousHostingController(vc) else {
                return false
            }

            // `isKind(of:)` rather than `isMember(of:)`: custom container subclasses are common,
            // and a `MyNavigationController: UINavigationController` is just as much a container.
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
        /// The test is the *name*, not the type, because the name is what the exclusion is about.
        /// A developer-authored subclass — `CheckoutHostingController` — names itself perfectly well
        /// and is kept, as is any host naming itself through `EmbraceViewControllerCustomization`
        /// (which `emb_viewName` has already applied by this point). Only a generic host, whose name
        /// still carries its type parameters, is anonymous.
        ///
        /// Deliberately does not walk up to parents the way the block list does. A child view
        /// controller presented inside SwiftUI has a real class name of its own; only the host is
        /// anonymous. Note the block list still gets the first say, so under the default config
        /// (hosts blocked) none of this is reached.
        private static func isAnonymousHostingController(_ vc: UIViewController) -> Bool {
            guard vc is EmbraceIdentifiableHostingController else {
                return false
            }
            return vc.emb_viewName.contains("<")
        }
    }

    /// App-state transitions reach here from `iOSSessionLifecycle`'s `UIApplication` observers, by
    /// way of `ViewCaptureService`. Delivery is synchronous the whole way, and UIKit posts those
    /// notifications on the main thread, so this arrives on the thread the broker requires — the
    /// same one the appearance callbacks come in on.
    extension ScreenNavigationTracker: AppStateObserver {

        func appWillBackground(at time: Date) {
            broker.handle(.backgrounded(at: time))
        }

        func appDidForeground(at time: Date) {
            broker.handle(.foregrounded(at: time))
        }
    }

    /// Screens a developer declared with the public SwiftUI modifier, feeding the same broker as the
    /// automatic ones.
    ///
    /// Sharing the broker is the point. There is one screen timeline, so both producers have to pass
    /// the same dedup gate, occupy the same visible-screen bookkeeping, and be restorable after a
    /// backgrounding. A declared screen reporting straight to the state primitive would bypass all
    /// three and interleave a second, unreconciled stream into one span.
    ///
    /// No filtering is applied here: the block lists are matched against view controller classes,
    /// which a declared name has none of, and naming the screen *is* the developer opting in.
    extension ScreenNavigationTracker: ManualScreenReporting {

        func onManualScreenAppear(
            id: ObjectIdentifier,
            name: String,
            attributes: EmbraceAttributes,
            at time: Date
        ) {
            // Refused rather than recorded: downstream equality is by name, so a screen declared
            // with a sentinel's name would swallow the real transition it collides with — a session
            // that genuinely backgrounded would report that it never did. Reported, because unlike
            // the feature being switched off this is a mistake the developer can fix.
            guard !Screen.isReserved(name) else {
                Embrace.logger.warning(
                    "Screen tracking: the screen name \"\(name)\" is reserved by the SDK and was "
                        + "ignored. Choose a different name for this screen.")
                return
            }

            // SwiftUI has no equivalent of the will/did appear split, so the start is synthesized at
            // the same instant. That is not a lost measurement: `onAppear` is the earliest signal the
            // framework offers, so there is no earlier moment to backdate the load to, and emitting
            // both keeps the resume rule's "no start means nothing to attribute" guard satisfied
            // instead of needing a manual-only exception inside the broker.
            broker.handle(.started(id, name: name, at: time))
            broker.handle(.resumed(id, name: name, at: time, attributes: attributes))
        }

        func onManualScreenDisappear(id: ObjectIdentifier, name: String, at time: Date) {
            broker.handle(.paused(id, name: name, at: time))
        }
    }
#endif
