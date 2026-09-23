//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Reconciles raw container lifecycle events into a single timeline of *distinct* screens, with
/// load times attributed to when the user started navigating rather than when we heard about it.
///
/// "What screen is the user on?" has no single source of truth: appearance callbacks fire per view
/// controller, overlap during transitions, and replay. This type is the arbiter.
///
/// ## Threading
/// Ordering *is* the correctness mechanism, so events are processed serially on the main queue and
/// the state below is deliberately unsynchronized. ``handle(_:)`` drops anything arriving off the
/// main queue and reports it, rather than trusting the contract silently.
///
/// Checked rather than asserted: `dispatchPrecondition` survives release builds, and this type is
/// fed by a swizzle on every `UIViewController` in the host app. Losing a transition beats
/// terminating a customer's process.
///
/// ## Not handled yet
/// Observing SwiftUI `NavigationStack` destinations will let a container's visible screen change
/// with no appearance callback, needing two further rules on a resume. Both are additive; the maps
/// and the emission funnel are shaped to take them.
final class NavigationEventBroker {

    /// What was last handed downstream, for the dedup gate below.
    ///
    /// Storing the *emission* rather than its triggering event is equivalent only while every
    /// emission carries its own event's name — which stops holding once the destination rules
    /// above arrive. Revisit it alongside them.
    private struct Emission: Equatable {
        let name: String
        let componentId: ObjectIdentifier?
    }

    /// Containers that have started appearing but not yet finished. The value is what a resume
    /// backdates its load time to.
    private var startTimes: [ObjectIdentifier: Date] = [:]

    /// The screen currently visible per container. More than one entry means a transition is in
    /// flight, which is what suppresses backdating.
    private var visibleScreens: [ObjectIdentifier: String] = [:]

    private var lastEmission: Emission?

    /// What was on screen when the app backgrounded, so foregrounding can restore it.
    private var screenBeforeBackground: Emission?

    /// Called with `(loadTime, screenName)` for each *distinct* screen the timeline moves to.
    private let onScreenLoad: (Date, String) -> Void

    init(onScreenLoad: @escaping (Date, String) -> Void) {
        self.onScreenLoad = onScreenLoad
    }

    // MARK: - Input

    func handle(_ event: NavigationEvent) {
        guard Thread.isMainThread else {
            Embrace.logger.error(
                "Screen tracking: a navigation event arrived off the main thread and was dropped. "
                    + "Appearance callbacks must be delivered on the main thread.")
            return
        }

        switch event.kind {
        case .started:
            guard let componentId = event.componentId else { return }
            // Keep the earliest: a swizzled subclass reports, runs its body, then calls `super`
            // which reports again. Overwriting would exclude exactly the work being measured. A
            // pause clears the entry, so a genuine second appearance still starts fresh.
            if startTimes[componentId] == nil {
                startTimes[componentId] = event.timestamp
            }

        case .resumed:
            guard let componentId = event.componentId else { return }
            // No matching start means this container never began appearing as far as we saw, so
            // there is nothing to attribute a load to.
            guard let startTime = startTimes.removeValue(forKey: componentId) else { return }

            visibleScreens[componentId] = event.name
            emit(name: event.name, componentId: componentId, at: loadTime(startTime, or: event.timestamp))

        case .paused:
            guard let componentId = event.componentId else { return }
            visibleScreens.removeValue(forKey: componentId)
            // Start time and restore point go too. `ObjectIdentifier` is a live object's address, so
            // an entry left by a deallocated controller can be inherited by an unrelated one
            // allocated there later — silently backdating its load, or restoring it as though the
            // user were still on it.
            startTimes.removeValue(forKey: componentId)

            if screenBeforeBackground?.componentId == componentId {
                screenBeforeBackground = nil
            }

        case .backgrounded:
            // Captured before the emission below overwrites `lastEmission`. Guarding on a non-nil
            // component id keeps a second background from "restoring" the Backgrounded sentinel.
            if let lastEmission, lastEmission.componentId != nil {
                screenBeforeBackground = lastEmission
            }
            emit(name: Screen.backgrounded.name, componentId: nil, at: event.timestamp)

        case .foregrounded:
            // UIKit does not re-fire appearance callbacks for the controller that stayed visible,
            // so without this the state sits on the sentinel until the user happens to navigate.
            // Load time is the foreground time; no start time exists to backdate to.
            guard let restored = screenBeforeBackground else { return }
            screenBeforeBackground = nil
            emit(name: restored.name, componentId: restored.componentId, at: event.timestamp)
        }
    }

    // MARK: - Rules

    /// Backdate a load to when the container started appearing, **unless** more than one screen is
    /// visible.
    ///
    /// Navigation began when the window started becoming visible, not when it finished. The
    /// exception covers transitional overlap, where the change cannot be attributed to that start.
    private func loadTime(_ startTime: Date, or eventTime: Date) -> Date {
        visibleScreens.count > 1 ? eventTime : startTime
    }

    /// The dedup gate every emission funnels through: fire only if the container **or** the name
    /// differs from the last. The first always fires.
    ///
    /// Not the only dedup in the chain — the state primitive downstream drops *value*-equal
    /// consecutive transitions, so two containers resolving to the same name pass here and are
    /// dropped there.
    private func emit(name: String, componentId: ObjectIdentifier?, at loadTime: Date) {
        let emission = Emission(name: name, componentId: componentId)
        defer { lastEmission = emission }

        guard lastEmission != emission else { return }
        onScreenLoad(loadTime, name)
    }
}
