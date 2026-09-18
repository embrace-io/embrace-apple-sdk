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
/// Observing SwiftUI `NavigationStack` destinations would let a container's visible screen change
/// with no appearance callback, needing two further rules on a resume. The maps and the emission
/// funnel are shaped to take them.
final class NavigationEventBroker {

    /// What makes one screen different from another: the container it came from and the screen
    /// itself, which is its name *and* its type.
    ///
    /// Attributes are deliberately excluded — a view re-rendering with a changed value is not a
    /// navigation.
    private struct ScreenIdentity: Equatable {
        let screen: Screen
        let componentId: ObjectIdentifier?
    }

    /// An emission is its identity plus the payload that rode along with it.
    private struct Emission {
        let identity: ScreenIdentity

        /// The most recent *declaration*, not the most recent emission — `emit` records the attempt
        /// even when the gate suppresses it. A restore therefore carries the screen's current
        /// metadata rather than a stale copy from whenever it last passed.
        let attributes: EmbraceAttributes
    }

    /// Containers that have started appearing but not yet finished. The value is what a resume
    /// backdates its load time to.
    private var startTimes: [ObjectIdentifier: Date] = [:]

    /// The screen currently visible per container. More than one entry means a transition is in
    /// flight, which is what suppresses backdating.
    private var visibleScreens: [ObjectIdentifier: Emission] = [:]

    /// What was last handed downstream, for the dedup gate below.
    ///
    /// Storing what was *emitted* is only equivalent to storing the event that triggered it for as
    /// long as every emission's value is its own event's name. That stops holding once the
    /// destination rules above arrive — a background restore emits a destination name while its
    /// triggering event carries the container's name — so revisit this alongside them.
    private var lastEmission: Emission?

    /// What was on screen when the app backgrounded, so foregrounding can restore it.
    private var screenBeforeBackground: Emission?

    /// Called with `(loadTime, screen, attributes)` for each *distinct* screen the timeline moves
    /// to. Attributes are empty for every screen except those declared with their own.
    private let onScreenLoad: (Date, Screen, EmbraceAttributes) -> Void

    init(onScreenLoad: @escaping (Date, Screen, EmbraceAttributes) -> Void) {
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

            // Untyped: every producer feeding this broker names screens after the app — a
            // developer's string or a view controller's class.
            let identity = ScreenIdentity(screen: Screen(event.name), componentId: componentId)
            visibleScreens[componentId] = Emission(identity: identity, attributes: event.attributes)
            emit(
                identity,
                attributes: event.attributes,
                at: loadTime(startTime, or: event.timestamp))

        case .paused:
            guard let componentId = event.componentId else { return }
            visibleScreens.removeValue(forKey: componentId)
            // Start time and restore point go too: `ObjectIdentifier` is a live object's address, so
            // an entry left behind can be inherited by an unrelated object allocated there later.
            startTimes.removeValue(forKey: componentId)

            if screenBeforeBackground?.identity.componentId == componentId {
                screenBeforeBackground = nil
            }

            revealScreenUncovered(by: componentId, at: event.timestamp)

        case .backgrounded:
            // Captured before the emission below overwrites `lastEmission`. Guarding on a non-nil
            // component id keeps a second background from "restoring" the Backgrounded sentinel.
            if let lastEmission, lastEmission.identity.componentId != nil {
                screenBeforeBackground = lastEmission
            }

            // Nothing is visible or mid-appearance while backgrounded, so both maps can be emptied
            // rather than waiting for a pause that may never come — one that never arrives would
            // otherwise disable backdating for every later screen.
            visibleScreens.removeAll()
            startTimes.removeAll()

            emit(
                ScreenIdentity(screen: .backgrounded, componentId: nil),
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

    /// Hands the timeline back to the screen left underneath the one that just went away.
    ///
    /// A sheet, popover or alert leaves the screen beneath it appeared, so nothing re-declares it on
    /// dismissal and the timeline would sit on the dismissed screen until the user navigated.
    ///
    /// Requires that the paused screen is the one currently shown and exactly one remains; anything
    /// else is a transition in flight, where the resume that follows will say what is frontmost.
    private func revealScreenUncovered(by pausedId: ObjectIdentifier, at time: Date) {
        guard lastEmission?.identity.componentId == pausedId,
            visibleScreens.count == 1,
            let revealed = visibleScreens.values.first
        else {
            return
        }

        // The load time is the dismissal: it did not load now, it became current now.
        emit(revealed.identity, attributes: revealed.attributes, at: time)
    }

    /// The dedup gate every emission funnels through: fire only if the container **or** the screen
    /// differs from the last. The first always fires.
    ///
    /// Not the only dedup in the chain — the state primitive downstream drops *value*-equal
    /// consecutive transitions, so two containers resolving to the same name pass here and are
    /// dropped there.
    private func emit(
        _ identity: ScreenIdentity,
        attributes: EmbraceAttributes,
        at loadTime: Date
    ) {
        defer { lastEmission = Emission(identity: identity, attributes: attributes) }

        guard lastEmission?.identity != identity else { return }
        onScreenLoad(loadTime, identity.screen, attributes)
    }
}
