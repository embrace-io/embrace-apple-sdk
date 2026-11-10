//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Reconciles screen lifecycle callbacks into a single timeline of *distinct* screens, with load
/// times attributed to when the user started navigating rather than when we heard about it, and
/// records that timeline as the `screen-automatic` state.
///
/// "What screen is the user on?" has no single source of truth: appearance callbacks fire per view
/// controller, overlap during transitions, and replay. This type is the arbiter. View controllers
/// (filtered by ``ViewCaptureService``), screens declared with `.embraceScreen`, and app-state
/// changes all feed the same timeline, so they share one dedup gate, one visible-screen bookkeeping
/// and one background restore.
///
/// ## Threading
/// Ordering *is* the correctness mechanism, so callbacks are processed serially on the main queue
/// and the state below is deliberately unsynchronized. Anything arriving off the main queue is
/// dropped and reported, rather than trusting the contract silently.
///
/// Checked rather than asserted: `dispatchPrecondition` survives release builds, and this type is
/// fed by a swizzle on every `UIViewController` in the host app. Losing a transition beats
/// terminating a customer's process.
final class ScreenTrackingHandler {

    /// The `<name>` in `emb-state-<name>` and `emb.state.<name>`. Wire contract.
    static let stateName = "screen-automatic"

    /// Per-session-part ceiling on recorded transitions. Overflow is counted in
    /// `emb.state.dropped_by_instrumentation`, never recorded.
    static let maxTransitions = 1000

    /// The live handler, for the SwiftUI modifier: a view modifier is constructed by the host app,
    /// with no route to the SDK's object graph.
    ///
    /// `nil` whenever screen tracking is not running, which is what makes the modifier a silent
    /// no-op then.
    static var current: ScreenTrackingHandler? {
        currentHandler.withLock { $0.handler }
    }

    /// Weak, so this never keeps a handler alive past its owner.
    private struct WeakHandler {
        weak var handler: ScreenTrackingHandler?
    }

    private static let currentHandler = EmbraceMutex(WeakHandler())

    static func makeCurrent(_ handler: ScreenTrackingHandler) {
        currentHandler.withLock { $0.handler = handler }
    }

    /// Clears ``current`` only if it is still `handler`, so a stale owner stopping cannot withdraw
    /// a newer one.
    static func resignCurrent(_ handler: ScreenTrackingHandler) {
        currentHandler.withLock {
            if $0.handler === handler {
                $0.handler = nil
            }
        }
    }

    /// What makes one screen different from another: the container it came from and the screen
    /// itself, which is its name *and* whether it is a system value.
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

    /// Records the timeline. Starts at ``Screen/initializing``, so a session in which the user never
    /// navigates still reports their screen.
    let recorder: StateRecorder<Screen>

    private let sanitizer: OTelSignalsSanitizer

    /// Containers that have started appearing but not yet finished. The value is what a resume
    /// backdates its load time to.
    private var startTimes: [ObjectIdentifier: Date] = [:]

    /// The screen currently visible per container. More than one entry means a transition is in
    /// flight, which is what suppresses backdating.
    private var visibleScreens: [ObjectIdentifier: Emission] = [:]

    /// What was last handed to the recorder, for the dedup gate below.
    private var lastEmission: Emission?

    /// What was on screen when the app backgrounded, so foregrounding can restore it.
    private var screenBeforeBackground: Emission?

    /// What was visible when the app backgrounded, put back on foreground: a screen left under a sheet
    /// is still there afterwards, and dismissing the sheet has to find it.
    private var visibleScreensBeforeBackground: [ObjectIdentifier: Emission] = [:]

    init(otel: EmbraceOTelSignalsHandler?, sanitizer: OTelSignalsSanitizer = DefaultOtelSignalsSanitizer()) {
        self.recorder = StateRecorder(
            stateName: Self.stateName,
            initialValue: .initializing,
            otel: otel,
            maxTransitions: Self.maxTransitions
        )
        self.sanitizer = sanitizer
    }

    // MARK: - Screens

    /// A container began appearing (`viewWillAppear`). Records a start time; emits nothing.
    ///
    /// - Parameter id: **Instance** identity of the container, not its class — two instances of the
    ///   same controller class must not collapse into one.
    func screenWillAppear(_ id: ObjectIdentifier, name: String, at time: Date) {
        guard isOnMainThread(),
            screenName(name, warningIfBlank: "a view controller resolved to a blank screen name") != nil
        else {
            return
        }
        start(id, at: time)
    }

    /// A container finished appearing (`viewDidAppear`). This is what drives a transition.
    ///
    /// Blank names were already reported by the ``screenWillAppear(_:name:at:)`` that precedes this.
    func screenDidAppear(_ id: ObjectIdentifier, name: String, attributes: EmbraceAttributes = [:], at time: Date) {
        guard isOnMainThread(), let name = screenName(name) else {
            return
        }
        resume(id, screen: Screen(name), attributes: attributes, at: time)
    }

    /// A container finished disappearing (`viewDidDisappear`).
    ///
    /// Needs no name: a pause emits nothing of its own and only clears bookkeeping, so it stays
    /// correct even for a container that was never tracked.
    func screenDidDisappear(_ id: ObjectIdentifier, at time: Date) {
        guard isOnMainThread() else {
            return
        }
        pause(id, at: time)
    }

    /// A screen declared with the public SwiftUI modifier became visible.
    ///
    /// No filtering is applied: the block lists are matched against view controller classes, which a
    /// declared name has none of, and naming the screen *is* the developer opting in.
    ///
    /// - Parameter id: Identity of the *view instance*, so two views showing the same name are still
    ///   two screens.
    func manualScreenAppeared(id: ObjectIdentifier, name: String, attributes: EmbraceAttributes, at time: Date) {
        guard isOnMainThread(),
            let name = screenName(name, warningIfBlank: "a screen was declared with a blank name")
        else {
            return
        }

        // SwiftUI has no equivalent of the will/did appear split, so the start is synthesized at the
        // same instant. That is not a lost measurement: `onAppear` is the earliest signal the
        // framework offers, so there is no earlier moment to backdate the load to, and starting it
        // keeps the resume rule's "no start means nothing to attribute" guard satisfied instead of
        // needing a manual-only exception.
        start(id, at: time)
        resume(id, screen: Screen(name), attributes: attributes, at: time)
    }

    func manualScreenDisappeared(id: ObjectIdentifier, at time: Date) {
        screenDidDisappear(id, at: time)
    }

    // MARK: - Rules

    private func start(_ id: ObjectIdentifier, at time: Date) {
        // Keep the earliest: a swizzled subclass reports, runs its body, then calls `super` which
        // reports again. Overwriting would exclude exactly the work being measured. A pause clears
        // the entry, so a genuine second appearance still starts fresh.
        if startTimes[id] == nil {
            startTimes[id] = time
        }
    }

    private func resume(_ id: ObjectIdentifier, screen: Screen, attributes: EmbraceAttributes, at time: Date) {
        // No matching start means this container never began appearing as far as we saw, so there
        // is nothing to attribute a load to.
        guard let startTime = startTimes.removeValue(forKey: id) else { return }

        let identity = ScreenIdentity(screen: screen, componentId: id)
        visibleScreens[id] = Emission(identity: identity, attributes: attributes)
        emit(identity, attributes: attributes, at: loadTime(startTime, or: time))
    }

    private func pause(_ id: ObjectIdentifier, at time: Date) {
        visibleScreens.removeValue(forKey: id)
        // Start time and restore point go too: `ObjectIdentifier` is a live object's address, so an
        // entry left behind can be inherited by an unrelated object allocated there later.
        startTimes.removeValue(forKey: id)

        visibleScreensBeforeBackground.removeValue(forKey: id)
        if screenBeforeBackground?.identity.componentId == id {
            screenBeforeBackground = nil
        }

        revealScreenUncovered(at: time)
    }

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
    /// Requires that the screen currently shown is gone and exactly one remains; anything else is a
    /// transition in flight, where the resume that follows will say what is frontmost. "Gone" rather
    /// than "the one that just paused", so a stack that unwinds over several pauses is handled in
    /// whatever order they arrive. While backgrounded the screen shown is the sentinel, which belongs
    /// to no container, so nothing is revealed.
    private func revealScreenUncovered(at time: Date) {
        guard let shownId = lastEmission?.identity.componentId,
            visibleScreens[shownId] == nil,
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
    /// Not the only dedup in the chain — the recorder drops *value*-equal consecutive transitions,
    /// so two containers resolving to the same name pass here and are dropped there.
    private func emit(_ identity: ScreenIdentity, attributes: EmbraceAttributes, at loadTime: Date) {
        defer { lastEmission = Emission(identity: identity, attributes: attributes) }

        guard lastEmission?.identity != identity else { return }
        recorder.onStateChange(to: identity.screen, at: loadTime, attributes: attributes)
    }

    // MARK: - Input checks

    private func isOnMainThread() -> Bool {
        guard Thread.isMainThread else {
            Embrace.logger.error(
                "Screen tracking: a screen callback arrived off the main thread and was dropped. "
                    + "Screen callbacks must be delivered on the main thread.")
            return false
        }
        return true
    }

    /// Trims and truncates a screen name before it becomes part of the timeline, or returns `nil`
    /// for a blank one.
    ///
    /// A screen name is the one caller-supplied string that nothing downstream bounds. It is
    /// written as an attribute *value* on internal spans, which skip sanitization, and stamped on
    /// every log as `emb.state.<name>` — so an unbounded name is not one oversized field but one per
    /// log for the rest of the session. That applies to view controllers too: their name prefers
    /// `nameForViewControllerInEmbrace`, which is public API.
    ///
    /// Trimming matters as much as the length cap, and for a different reason. Equality downstream
    /// is by name, so `"Home"` and `"Home\n"` are two screens: the timeline shows a navigation the
    /// user never made.
    ///
    /// Treated as a *name* rather than an attribute value: a screen name is conceptually a name, and
    /// the 1024-character value budget would be far too large for something copied onto every log.
    ///
    /// A blank name is indistinguishable from an absent one downstream, and would still spend one of
    /// the part's transitions.
    private func screenName(_ name: String, warningIfBlank warning: String? = nil) -> String? {
        let name = sanitizer.sanitizeSpanEventName(name)
        guard !name.isEmpty else {
            if let warning {
                Embrace.logger.warning("Screen tracking: \(warning) and was ignored.")
            }
            return nil
        }
        return name
    }
}

/// App-state transitions arrive from `iOSSessionLifecycle`'s `UIApplication` observers. Delivery is
/// synchronous, and UIKit posts those notifications on the main thread, so this arrives on the
/// thread the timeline requires — the same one the appearance callbacks come in on.
extension ScreenTrackingHandler: AppStateObserver {

    /// From the SDK's app-state signal, so navigation and session backgrounding share one timestamp.
    func appWillBackground(at time: Date) {
        guard isOnMainThread() else {
            return
        }

        // Captured before the emission below overwrites `lastEmission`. Guarding on a non-nil
        // component id keeps a second background from "restoring" the Backgrounded sentinel.
        if let lastEmission, lastEmission.identity.componentId != nil {
            screenBeforeBackground = lastEmission
        }

        // Nothing is visible or mid-appearance while backgrounded. The visible set comes back on
        // foreground; a start that never finished does not.
        visibleScreensBeforeBackground = visibleScreens
        visibleScreens.removeAll()
        startTimes.removeAll()

        emit(ScreenIdentity(screen: .backgrounded, componentId: nil), attributes: [:], at: time)
    }

    func appDidForeground(at time: Date) {
        guard isOnMainThread() else {
            return
        }

        // Visible again, though nothing re-reports them: without this, dismissing a sheet would find
        // no screen underneath to hand the timeline back to.
        visibleScreens.merge(visibleScreensBeforeBackground) { current, _ in current }
        visibleScreensBeforeBackground.removeAll()

        // UIKit does not re-fire appearance callbacks for the controller that stayed visible, so
        // without this the state sits on the sentinel until the user happens to navigate. Load time
        // is the foreground time; no start time exists to backdate to. With nothing to restore (the
        // screen on display was never tracked) the state stays on the sentinel until one appears.
        guard let restored = screenBeforeBackground else { return }
        screenBeforeBackground = nil
        if let componentId = restored.identity.componentId {
            visibleScreens[componentId] = restored
        }
        // Replayed with the screen's metadata rather than stripped of it — see `Emission` for which
        // declaration that is when the screen was re-declared while the user stayed on it.
        emit(restored.identity, attributes: restored.attributes, at: time)
    }
}
