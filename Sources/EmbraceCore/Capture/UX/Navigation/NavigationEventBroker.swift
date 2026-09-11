//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

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

    /// What makes one screen different from another: the container it came from and its name.
    ///
    /// Storing the *emission* rather than its triggering event is equivalent only while every
    /// emission carries its own event's name — which stops holding once the destination rules
    /// above arrive. Revisit it alongside them.
    private struct ScreenIdentity: Equatable {
        let name: String
        let componentId: ObjectIdentifier?
    }

    /// An emission is its identity plus the payload that rode along with it.
    ///
    /// Two types rather than one with a hand-written `==` ignoring a stored property: that operator
    /// would mean equal values are not interchangeable, and any later `Hashable` or `Set` use would
    /// inherit it. Here `ScreenIdentity` gets synthesized equality and `Emission` has no operator to
    /// misuse.
    private struct Emission {
        let identity: ScreenIdentity

        /// Tracks the most recent *declaration*, not the most recent emission: `emit` records the
        /// attempt even when the dedup gate suppresses it. So a screen re-declared with fresher
        /// values while the user stays on it restores with those fresher values, even though they
        /// never shipped a transition of their own. That is the intent — a restore says "the user is
        /// back on this screen", and the screen's current metadata describes it better than a stale
        /// copy from whenever it last passed the gate.
        let attributes: EmbraceAttributes
    }

    /// Containers that have started appearing but not yet finished. The value is what a resume
    /// backdates its load time to.
    private var startTimes: [ObjectIdentifier: Date] = [:]

    /// The screen currently visible per container. More than one entry means a transition is in
    /// flight, which is what suppresses backdating.
    private var visibleScreens: [ObjectIdentifier: String] = [:]

    /// What was last handed downstream, for the dedup gate below.
    ///
    /// Storing what was *emitted* is only equivalent to storing the event that triggered it for as
    /// long as every emission's value is its own event's name. That stops holding once the
    /// destination rules above arrive — a background restore emits a destination name while its
    /// triggering event carries the container's name — so revisit this alongside them.
    private var lastEmission: Emission?

    /// What was on screen when the app backgrounded, so foregrounding can restore it.
    private var screenBeforeBackground: Emission?

    /// Called with `(loadTime, screenName, attributes)` for each *distinct* screen the timeline
    /// moves to. Attributes are empty for every screen except those declared with their own.
    private let onScreenLoad: (Date, String, EmbraceAttributes) -> Void

    init(onScreenLoad: @escaping (Date, String, EmbraceAttributes) -> Void) {
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
            emit(
                ScreenIdentity(name: event.name, componentId: componentId),
                attributes: event.attributes,
                at: loadTime(startTime, or: event.timestamp))

        case .paused:
            guard let componentId = event.componentId else { return }
            visibleScreens.removeValue(forKey: componentId)
            // Start time and restore point go too. `ObjectIdentifier` is a live object's address, so
            // an entry left by a deallocated controller can be inherited by an unrelated one
            // allocated there later — silently backdating its load, or restoring it as though the
            // user were still on it.
            startTimes.removeValue(forKey: componentId)

            if screenBeforeBackground?.identity.componentId == componentId {
                screenBeforeBackground = nil
            }

        case .backgrounded:
            // Captured before the emission below overwrites `lastEmission`. Guarding on a non-nil
            // component id keeps a second background from "restoring" the Backgrounded sentinel.
            if let lastEmission, lastEmission.identity.componentId != nil {
                screenBeforeBackground = lastEmission
            }
            emit(
                ScreenIdentity(name: Screen.backgrounded.name, componentId: nil),
                attributes: [:],
                at: event.timestamp)

        case .foregrounded:
            // UIKit does not re-fire appearance callbacks for the controller that stayed visible,
            // so without this the state sits on the sentinel until the user happens to navigate.
            // Load time is the foreground time; no start time exists to backdate to.
            guard let restored = screenBeforeBackground else { return }
            screenBeforeBackground = nil
            // Replayed with the screen's metadata rather than stripped of it — see `Emission` for
            // which declaration that is when the screen was re-declared while the user stayed on it.
            emit(restored.identity, attributes: restored.attributes, at: event.timestamp)
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
    /// This is what collapses replayed and duplicated callbacks into a timeline of distinct
    /// `(container, screen)` states. Note it is not the only dedup in the chain — the state
    /// primitive downstream drops *value*-equal consecutive transitions and counts them, so moving
    /// between two different containers with the same name passes this gate and is dropped there.
    private func emit(
        _ identity: ScreenIdentity,
        attributes: EmbraceAttributes,
        at loadTime: Date
    ) {
        defer { lastEmission = Emission(identity: identity, attributes: attributes) }

        guard lastEmission?.identity != identity else { return }
        onScreenLoad(loadTime, identity.name, attributes)
    }
}
