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
/// It deliberately does **not** use `dispatchPrecondition`: that bottoms out in libdispatch's
/// `dispatch_assert_queue`, which traps in every optimisation level including `-Ounchecked`, and
/// this type is fed by a swizzle installed on every `UIViewController` in the host app. An app that
/// drives an appearance callback off the main thread would then crash *because this SDK is linked*.
/// Losing a screen transition is the right trade against terminating a customer's process.
///
/// ## Not handled yet
/// Every screen name here comes from the container itself. Once SwiftUI `NavigationStack`
/// destinations are observed, a container's visible screen will be able to change with no
/// appearance callback at all, which needs two further rules on a resume: re-emitting the last known
/// destination for a container coming back from the background, and suppressing the resume that
/// follows a destination change on first display. Both are additive — the maps and the emission
/// funnel below are shaped to take them.
final class NavigationEventBroker {

    /// What was last handed downstream, for the dedup gate below.
    ///
    /// Storing what was *emitted* is only equivalent to storing the event that triggered it for as
    /// long as every emission's value is its own event's name. That stops holding once the
    /// destination rules above arrive — a background restore emits a destination name while its
    /// triggering event carries the container's name — so revisit this alongside them.
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
            startTimes[componentId] = event.timestamp

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
            // The start time goes too. `ObjectIdentifier` is the address of a live object, so one
            // left behind by a deallocated controller could be picked up by an unrelated controller
            // allocated at the same address, silently backdating its load.
            startTimes.removeValue(forKey: componentId)

        case .backgrounded:
            // Captured before the emission below overwrites `lastEmission`. Guarding on a non-nil
            // component id keeps a second background from "restoring" the Backgrounded sentinel.
            if let lastEmission, lastEmission.componentId != nil {
                screenBeforeBackground = lastEmission
            }
            emit(name: Screen.backgrounded.name, componentId: nil, at: event.timestamp)

        case .foregrounded:
            // UIKit does not re-fire appearance callbacks for a controller that stayed the visible
            // one, so nothing else would move the state off the Backgrounded sentinel until the
            // user happened to navigate. Load time is the foreground time — no new start time
            // exists to backdate to.
            guard let restored = screenBeforeBackground else { return }
            screenBeforeBackground = nil
            emit(name: restored.name, componentId: restored.componentId, at: event.timestamp)
        }
    }

    // MARK: - Rules

    /// Backdate a load to when the container started appearing, **unless** more than one screen is
    /// visible.
    ///
    /// Backdating is product semantics: navigation began when the window started becoming visible,
    /// not when it finished. The exception exists because during fast switches or transitional
    /// overlap the change cannot be attributed to that earlier start, so the event's own time wins.
    private func loadTime(_ startTime: Date, or eventTime: Date) -> Date {
        visibleScreens.count > 1 ? eventTime : startTime
    }

    /// The dedup gate every emission funnels through: fire only if the container **or** the name
    /// differs from the last emission. The first always fires.
    ///
    /// This is what collapses replayed and duplicated callbacks into a timeline of distinct
    /// `(container, screen)` states. Note it is not the only dedup in the chain — the state
    /// primitive downstream drops *value*-equal consecutive transitions and counts them, so moving
    /// between two different containers with the same name passes this gate and is dropped there.
    private func emit(name: String, componentId: ObjectIdentifier?, at loadTime: Date) {
        let emission = Emission(name: name, componentId: componentId)
        defer { lastEmission = emission }

        guard lastEmission != emission else { return }
        onScreenLoad(loadTime, name)
    }
}
