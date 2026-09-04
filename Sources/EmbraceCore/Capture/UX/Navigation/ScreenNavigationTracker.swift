//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit

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
        ///
        /// Android had no equivalent need; its Activity granularity is already this coarse.
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
            guard shouldTrack(vc) else {
                return
            }

            let componentId = ObjectIdentifier(vc)
            let name = vc.emb_viewName

            switch phase {
            case .willAppear:
                broker.handle(.started(componentId, name: name, at: time))
            case .didAppear:
                broker.handle(.resumed(componentId, name: name, at: time))
            case .didDisappear:
                broker.handle(.paused(componentId, name: name, at: time))
            }
        }

        func onForeground(at time: Date) {
            broker.handle(.foregrounded(at: time))
        }

        func onBackground(at time: Date) {
            broker.handle(.backgrounded(at: time))
        }

        // MARK: - Filtering

        private func shouldTrack(_ vc: UIViewController) -> Bool {
            // Reuses the view instrumentation's existing exclusions rather than inventing a second
            // set, so a controller a customer has already opted out of stays out of both streams.
            guard vc.emb_shouldCaptureView, !isBlocked(vc) else {
                return false
            }

            // `isKind(of:)` rather than `isMember(of:)`: custom container subclasses are common,
            // and a `MyNavigationController: UINavigationController` is just as much a container.
            return !Self.containerClasses.contains { vc.isKind(of: $0) }
        }
    }
#endif
