//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Tracks the screen-load vital: the time from a user's tap until the destination screen's first frame
/// after navigation end. A port of Android's `ScreenLoadTracker`, minus settle detection: where Android
/// waits for the destination to go quiet, iOS completes at the first frame and reports it as
/// ``ScreenLoadOutcome/timedOut``, which is what Android reports for that same first-frame end.
///
/// The tracker is a pure state machine with no UIKit or QuartzCore dependency. Navigation start and end
/// are plain inputs, so any navigation source (UIKit now, possibly SwiftUI later) can drive it.
///
/// All times are seconds on the system uptime base (`ProcessInfo.systemUptime`, which is also the base
/// of `UIEvent.timestamp` and `CACurrentMediaTime()`), except ``ScreenLoadResult/startTime`` which is
/// wall-clock.
///
/// Not synchronized: every call, and the injected scheduler's timeout callback, must run on the same
/// serial queue.
final class ScreenLoadTracker {

    /// Schedules the work item that times out the current load. The item must run on the tracker's queue.
    typealias TimeoutScheduler = (_ delay: TimeInterval, _ item: DispatchWorkItem) -> Void

    /// Maximum time from a load's start until it is force-reported (or discarded, if it never reached
    /// navigation end).
    static let defaultTimeout: TimeInterval = 30

    /// The maximum time between a tap and a navigation start for the two to be linked into one load.
    static let defaultNavigationTimeout: TimeInterval = 0.5

    /// iOS has no settle detection, so no idle threshold is ever applied.
    private static let idleThresholdMs = 0

    private let timeout: TimeInterval
    private let navigationTimeout: TimeInterval
    private let uptimeProvider: () -> TimeInterval
    private let dateProvider: () -> Date
    private let scheduleTimeout: TimeoutScheduler
    private let emit: (ScreenLoadResult) -> Void

    private var state = State.idle
    private var screenName = ""
    private var startUptime: TimeInterval = 0
    private var startTime = Date(timeIntervalSince1970: 0)

    // When the navigation start confirmed the candidate as a real screen load.
    private var navigationStartUptime: TimeInterval = 0

    // When navigation end moved the load to waiting for its first frame.
    private var navigationEndUptime: TimeInterval = 0

    // The latest activity while waiting: the latest navigation end. Interrupted loads end here. Android
    // also counts frames and window focus, but on iOS the first frame completes the load.
    private var lastActivity: TimeInterval = 0

    // The first frame after navigation end, set only as the load completes on it.
    private var firstFrame: TimeInterval?

    // The armed timeout. Discarding cancels it, so a load's timeout can never fire against a later load.
    private var timeoutWorkItem: DispatchWorkItem?

    /// - Parameters:
    ///   - queue: The serial queue every call runs on. The default scheduler runs the timeout there.
    ///   - timeout: Maximum time from a load's start until it is force-reported.
    ///   - navigationTimeout: Maximum tap-to-navigation-start gap linking the two into one load.
    ///   - uptimeProvider: The current system uptime.
    ///   - dateProvider: The current wall-clock time.
    ///   - scheduleTimeout: Schedules the timeout. It defaults to `asyncAfter` on `queue`; tests pass
    ///     their own so they can fire it themselves.
    ///   - emit: Receives each completed load.
    init(
        queue: DispatchQueue,
        timeout: TimeInterval = ScreenLoadTracker.defaultTimeout,
        navigationTimeout: TimeInterval = ScreenLoadTracker.defaultNavigationTimeout,
        uptimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        dateProvider: @escaping () -> Date = Date.init,
        scheduleTimeout: TimeoutScheduler? = nil,
        emit: @escaping (ScreenLoadResult) -> Void
    ) {
        self.timeout = timeout
        self.navigationTimeout = navigationTimeout
        self.uptimeProvider = uptimeProvider
        self.dateProvider = dateProvider
        self.scheduleTimeout =
            scheduleTimeout ?? { delay, item in
                queue.asyncAfter(deadline: .now() + delay, execute: item)
            }
        self.emit = emit
    }

    /// A committed tap (touch up) opens a fresh candidate load, anchored at `time`, discarding any load
    /// still navigating. If a navigation start follows within the navigation timeout, the load starts
    /// at this tap.
    ///
    /// If the prior load was already waiting for its first frame, the user acted on a screen that was
    /// ready enough to touch: it is emitted as ``ScreenLoadOutcome/userInterrupted`` rather than dropped.
    func tap(at time: TimeInterval? = nil) {
        let time = time ?? uptimeProvider()

        if state == .waitingForFrame {
            complete(end: lastActivity, outcome: .userInterrupted)
        } else {
            // The user is no longer waiting on a load that is still navigating. Discarding also cancels
            // its timeout, which would otherwise fire against this new candidate.
            discard()
        }

        state = .candidate
        beginLoad(at: time)
    }

    /// A navigation start confirms a real screen load: from the candidate tap if it was recent enough,
    /// otherwise from `time`. A `name` known here is recorded as the destination's name.
    func navigationStart(name: String? = nil, at time: TimeInterval? = nil) {
        let time = time ?? uptimeProvider()

        switch state {
        case .idle:
            openLoad(at: time)
        case .candidate:
            if time <= startUptime + navigationTimeout {
                state = .confirmed
                navigationStartUptime = time
                // The candidate is now a real load, so start its timeout.
                armTimeout()
            } else {
                // The tap is too far in the past to be part of this load, so it starts now.
                openLoad(at: time)
            }
        case .confirmed:
            break
        case .waitingForFrame:
            // Flush the current load before starting another one.
            complete(end: lastActivity, outcome: .navigationInterrupted)
            openLoad(at: time)
        }

        // Make sure the name isn't left over from a previous navigation.
        screenName = name ?? ""
    }

    /// A navigation end records that the destination was reached, updating its name if `name` is
    /// given, and moves the load to waiting for its first frame.
    func navigationEnd(name: String? = nil, at time: TimeInterval? = nil) {
        guard state == .confirmed || state == .waitingForFrame else {
            return
        }

        let time = time ?? uptimeProvider()

        if let name {
            screenName = name
        }

        if state == .confirmed {
            state = .waitingForFrame
            navigationEndUptime = time
        }

        lastActivity = max(lastActivity, time)
    }

    /// The first displayed frame after navigation end completes the load, ending at that frame.
    func frame(at time: TimeInterval) {
        guard state == .waitingForFrame else {
            return
        }

        // As on Android, the frame's timestamp is used as is, even if it is stamped before navigation end.
        firstFrame = time
        complete(end: time, outcome: .timedOut)
    }

    /// The load was interrupted (e.g. the app was backgrounded): abandon it, emitting nothing.
    func interrupt() {
        discard()
    }

    /// The load ran for the timeout without completing. Only a load that reached navigation end is a
    /// real screen load: it is reported ending at navigation end, since no frame arrived. Any other
    /// state is an incomplete sequence, and is discarded.
    private func onTimeout() {
        guard state == .waitingForFrame else {
            discard()
            return
        }

        complete(end: navigationEndUptime, outcome: .timedOut)
    }

    private func openLoad(at time: TimeInterval) {
        state = .confirmed
        beginLoad(at: time)
        navigationStartUptime = time
        armTimeout()
    }

    /// Anchors a new load at `time`, clearing the previous load's name.
    private func beginLoad(at time: TimeInterval) {
        screenName = ""
        startUptime = time
        startTime = wallClockTime(of: time)
    }

    private func complete(end: TimeInterval, outcome: ScreenLoadOutcome) {
        let result = ScreenLoadResult(
            startTime: startTime,
            durationMs: Self.milliseconds(end - startUptime),
            screenName: screenName,
            outcome: outcome,
            navStartDelayMs: Self.milliseconds(navigationStartUptime - startUptime),
            navDurationMs: Self.milliseconds(navigationEndUptime - navigationStartUptime),
            firstFrameDurationMs: firstFrame.map { Self.milliseconds($0 - navigationEndUptime) } ?? 0,
            idleThresholdMs: Self.idleThresholdMs,
            timeoutMs: Self.milliseconds(timeout),
            navTimeoutMs: Self.milliseconds(navigationTimeout)
        )

        discard()
        emit(result)
    }

    /// Arms the timeout. The window runs from the load's start (the tap that led to it), not from now,
    /// so it can be armed when the load is confirmed without moving the deadline. Clamped to the window
    /// length in case an event timestamp is skewed against the current clock.
    private func armTimeout() {
        let delay = min(max(startUptime + timeout - uptimeProvider(), 0), timeout)
        let item = DispatchWorkItem { [weak self] in
            self?.onTimeout()
        }
        timeoutWorkItem = item
        scheduleTimeout(delay, item)
    }

    private func discard() {
        state = .idle
        lastActivity = 0
        firstFrame = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    /// Converts an uptime to wall-clock, relative to the current time on both clocks.
    private func wallClockTime(of time: TimeInterval) -> Date {
        dateProvider().addingTimeInterval(time - uptimeProvider())
    }

    /// Rounds to the nearest millisecond, so floating-point error can't truncate e.g. 30ms to 29ms.
    private static func milliseconds(_ seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded())
    }

    /// The screen-load sequence is a strict linear progression, each step gated on the prior one, so a
    /// single state models it exactly.
    private enum State {
        /// No load in progress.
        case idle

        /// A committed tap opened a candidate, awaiting a navigation start. No timeout is armed while it
        /// waits, as a navigation start rejects a tap too old to belong to it.
        case candidate

        /// A navigation start confirmed the load, awaiting a navigation end.
        case confirmed

        /// A navigation end was reached, awaiting the destination's first frame. Android's `SETTLING`.
        case waitingForFrame
    }
}
