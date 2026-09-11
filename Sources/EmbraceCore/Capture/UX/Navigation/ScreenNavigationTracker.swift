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
    enum ScreenAppearancePhase {
        case willAppear
        case didAppear
        case didDisappear
    }

    /// Turns view controller appearance callbacks into the navigation timeline.
    ///
    /// Decides *which* controllers count as screens and what they are called; the broker decides
    /// what the resulting timeline looks like.
    ///
    /// Main-thread only, and nothing is dispatched — that satisfies the broker's serialization
    /// contract and keeps each transition on its originating callback's timestamp.
    final class ScreenNavigationTracker {

        /// Skipped: containers appear alongside the content they present, which would both put
        /// "UINavigationController" in the timeline and keep two screens visible at once —
        /// suppressing load-time backdating for the real one.
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
            // Normalized here too, not only on the declared path: `emb_viewName` prefers
            // `nameForViewControllerInEmbrace`, which is public API and just as unbounded as a
            // string passed to `.embraceScreen`. A class name is unaffected.
            let name = Self.normalized(vc.emb_viewName)

            switch phase {
            case .willAppear:
                guard shouldTrack(vc, named: name) else { return }
                broker.handle(.started(componentId, name: name, at: time))

            case .didAppear:
                guard shouldTrack(vc, named: name) else { return }
                broker.handle(.resumed(componentId, name: name, at: time))

            case .didDisappear:
                // Forwarded unconditionally: a pause emits nothing and only clears bookkeeping, so
                // it stays correct even for a controller the guards above refused.
                broker.handle(.paused(componentId, name: name, at: time))
            }
        }

        // MARK: - Filtering

        private func shouldTrack(_ vc: UIViewController, named name: String) -> Bool {
            guard !Screen.isReserved(name) else {
                Embrace.logger.warning(
                    "Screen tracking: \"\(name)\" is reserved by the SDK, so that screen was not "
                        + "recorded. Rename it, or report a different name for it with "
                        + "`nameForViewControllerInEmbrace`.")
                return false
            }

            return shouldTrack(vc)
        }

        private func shouldTrack(_ vc: UIViewController) -> Bool {
            // A controller the customer has already opted out of stays out of both streams.
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
        /// Naming it is an unconditional opt-in: a host that supplies
        /// `nameForViewControllerInEmbrace` is never anonymous, whatever it chose to call itself.
        /// The generic test would otherwise be applied to the developer's own string and reject
        /// `"Cart <checkout v2>"` — a deliberate name — for containing a character it never meant
        /// anything by.
        ///
        /// Failing that, the test is on the *class* name, since that is what produces the soup.
        /// `CheckoutHostingController` names itself perfectly well and is kept; a generic subclass
        /// like `ScreenHost<CheckoutView>` is not, and its escape hatch is the customization
        /// protocol above.
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

        /// Trims and truncates a screen name before it becomes part of the timeline.
        ///
        /// A screen name is the one caller-supplied string that nothing downstream bounds. It is
        /// written as an attribute *value* — `emb.state.new_value` on the transition,
        /// `emb.state.initial_value` on the span, and `emb.state.<name>` stamped on every log — and
        /// all of those live on internal spans, which skip sanitization entirely. So an unbounded
        /// name is not one oversized field: it is one per log for the rest of the session.
        ///
        /// Trimming matters as much as the length cap, and for a different reason. Equality
        /// downstream is by name, so `"Home"` and `"Home\n"` are two screens: the timeline shows a
        /// navigation the user never made, which is exactly the failure the modifier's own
        /// documentation warns against.
        ///
        /// Uses the SDK's own name treatment rather than the attribute-value one. A screen name is
        /// conceptually a name, the event-name budget is the right order of magnitude for one, and
        /// treating it as a 1024-character value would leave it far too large for something copied
        /// onto every log.
        private static func normalized(_ name: String) -> String {
            sanitizer.sanitizeName(name, lengthLimit: sessionLimits.events.nameLength)
        }

        private static let sanitizer = DefaultOtelSignalsSanitizer()
        private static let sessionLimits = SessionLimits()
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
            // Normalized before anything looks at it, so the checks below and the value that ships
            // are the same string. Checking the raw name would let `" Backgrounded "` past the
            // sentinel guard and still collide downstream, where equality is by name.
            let name = Self.normalized(name)

            // A blank name is indistinguishable from an absent one downstream, and still spends one
            // of the part's transitions.
            guard !name.isEmpty else {
                Embrace.logger.warning(
                    "Screen tracking: a screen was declared with a blank name and was ignored.")
                return
            }

            // A sentinel's name is worse than useless: equality downstream is by name, so it
            // swallows the real transition it collides with, and a session that genuinely
            // backgrounded reports that it never did.
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
