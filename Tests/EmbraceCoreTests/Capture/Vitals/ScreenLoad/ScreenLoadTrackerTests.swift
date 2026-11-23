//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// The screen-load tracker is a pure state machine, so it is driven with explicit timestamps and only
/// the results it emits are asserted.
///
/// The scenarios mirror Android's `ScreenLoadTrackerTest`, with the first frame standing in for settle:
/// where Android settles, iOS completes at the first frame after navigation end as `timed_out`.
/// Android's window-focus case has no iOS equivalent.
final class ScreenLoadTrackerTests: XCTestCase {

    /// One input to the tracker. Times are milliseconds after ``ScreenLoadTrackerTests/origin``.
    ///
    /// Every timed input first advances the clock to its time (if later), running any timeouts that
    /// fell due on the way, as the tracker's queue would have.
    private enum Step {
        case tap(Int)
        case navStart(String?, Int)
        case navEnd(String?, Int)
        case frame(Int)
        case interrupt
        case advance(to: Int)
    }

    private struct Scenario {
        let name: String
        let steps: [Step]
        let expected: [ScreenLoadResult]
    }

    /// Uptime of the first event, like a real `systemUptime`.
    private static let origin: TimeInterval = 1_000

    private var clock: ManualClock!
    private var emitted: [ScreenLoadResult] = []
    private var tracker: ScreenLoadTracker!

    override func setUp() {
        super.setUp()
        reset()
    }

    private func reset() {
        clock = ManualClock(uptime: Self.origin)
        emitted = []
        tracker = makeTracker()
    }

    // MARK: Scenarios

    func test_scenarios() {
        let scenarios: [Scenario] = [
            Scenario(
                name: "a tap, navigation and first frame is a timed-out screen load ending at the frame",
                steps: [.tap(0), .navStart("home", 20), .navEnd("home", 30), .frame(40)],
                expected: [result(start: 0, duration: 40, name: "home", outcome: .timedOut, navStartDelay: 20, navDuration: 10, firstFrame: 10)]
            ),
            Scenario(
                name: "navigation end anchors to its event time, not when it is delivered",
                steps: [.tap(0), .navStart("home", 0), .advance(to: 9), .navEnd("home", 0), .frame(0)],
                expected: [result(start: 0, duration: 0, name: "home", outcome: .timedOut, navStartDelay: 0, navDuration: 0, firstFrame: 0)]
            ),
            Scenario(
                name: "a touchless navigation opens the load anchored at the navigation",
                steps: [.navStart("detail", 0), .navEnd("detail", 15), .frame(25)],
                expected: [result(start: 0, duration: 25, name: "detail", outcome: .timedOut, navStartDelay: 0, navDuration: 15, firstFrame: 10)]
            ),
            Scenario(
                name: "a tap outside the navigation timeout starts the load at the navigation",
                steps: [.tap(0), .navStart("home", 501), .navEnd("home", 600), .frame(650)],
                expected: [result(start: 501, duration: 149, name: "home", outcome: .timedOut, navStartDelay: 0, navDuration: 99, firstFrame: 50)]
            ),
            Scenario(
                name: "a navigation start exactly at the navigation timeout is linked to the tap",
                steps: [.tap(0), .navStart("home", 500), .navEnd("home", 600), .frame(650)],
                expected: [result(start: 0, duration: 650, name: "home", outcome: .timedOut, navStartDelay: 500, navDuration: 100, firstFrame: 50)]
            ),
            Scenario(
                name: "no frame within the timeout times out at navigation end",
                steps: [.tap(0), .navStart("home", 100), .navEnd("home", 300), .advance(to: 30_000), .frame(30_010)],
                expected: [result(start: 0, duration: 300, name: "home", outcome: .timedOut, navStartDelay: 100, navDuration: 200, firstFrame: 0)]
            ),
            Scenario(
                name: "a tap while waiting ends the load as user-interrupted at its last activity, and opens a new candidate",
                steps: [
                    .tap(0), .navStart("home", 0), .navEnd("home", 0), .tap(50),
                    .navStart("next", 100), .navEnd("next", 120), .frame(130)
                ],
                expected: [
                    result(start: 0, duration: 0, name: "home", outcome: .userInterrupted, navStartDelay: 0, navDuration: 0, firstFrame: 0),
                    result(start: 50, duration: 80, name: "next", outcome: .timedOut, navStartDelay: 50, navDuration: 20, firstFrame: 10)
                ]
            ),
            Scenario(
                name: "a navigation while waiting ends the load as navigation-interrupted and opens a new one",
                steps: [.tap(0), .navStart("a", 0), .navEnd("a", 20), .navStart("b", 70), .navEnd("b", 70), .frame(90)],
                expected: [
                    result(start: 0, duration: 20, name: "a", outcome: .navigationInterrupted, navStartDelay: 0, navDuration: 20, firstFrame: 0),
                    result(start: 70, duration: 20, name: "b", outcome: .timedOut, navStartDelay: 0, navDuration: 0, firstFrame: 20)
                ]
            ),
            Scenario(
                name: "a repeated navigation end moves the last activity but not the navigation end",
                steps: [.tap(0), .navStart("a", 0), .navEnd("a", 20), .navEnd("a", 40), .navStart("b", 70)],
                expected: [result(start: 0, duration: 40, name: "a", outcome: .navigationInterrupted, navStartDelay: 0, navDuration: 20, firstFrame: 0)]
            ),
            Scenario(
                name: "a blank navigation-end name does not clobber a known screen name",
                steps: [.tap(0), .navStart("home", 0), .navEnd(nil, 10), .frame(20)],
                expected: [result(start: 0, duration: 20, name: "home", outcome: .timedOut, navStartDelay: 0, navDuration: 10, firstFrame: 10)]
            ),
            Scenario(
                name: "the navigation-end name wins over the navigation-start name",
                steps: [.tap(0), .navStart("a", 0), .navEnd("b", 10), .frame(20)],
                expected: [result(start: 0, duration: 20, name: "b", outcome: .timedOut, navStartDelay: 0, navDuration: 10, firstFrame: 10)]
            ),
            Scenario(
                name: "a second navigation start before navigation end only replaces the name",
                steps: [.tap(0), .navStart("a", 10), .navStart("b", 20), .navEnd(nil, 30), .frame(40)],
                expected: [result(start: 0, duration: 40, name: "b", outcome: .timedOut, navStartDelay: 10, navDuration: 20, firstFrame: 10)]
            ),
            Scenario(
                name: "a frame stamped before navigation end is used as is, like Android",
                steps: [.tap(0), .navStart("home", 10), .navEnd("home", 30), .frame(25)],
                expected: [result(start: 0, duration: 25, name: "home", outcome: .timedOut, navStartDelay: 10, navDuration: 20, firstFrame: -5)]
            ),
            Scenario(
                name: "frames outside waiting for the first frame are ignored",
                steps: [.frame(0), .tap(5), .frame(10), .navStart("home", 20), .frame(30), .navEnd("home", 40), .frame(50), .frame(60)],
                expected: [result(start: 5, duration: 45, name: "home", outcome: .timedOut, navStartDelay: 15, navDuration: 20, firstFrame: 10)]
            ),
            Scenario(
                name: "a timeout before navigation end is an incomplete sequence and emits nothing",
                steps: [.tap(0), .navStart("home", 0), .advance(to: 30_000), .navEnd("home", 30_010), .frame(30_020)],
                expected: []
            ),
            Scenario(
                name: "a navigation end with no navigation start is ignored",
                steps: [.navEnd("home", 0), .frame(10), .advance(to: 30_000)],
                expected: []
            ),
            Scenario(
                name: "a tap with no navigation emits nothing",
                steps: [.tap(0), .frame(10), .advance(to: 30_000)],
                expected: []
            ),
            Scenario(
                name: "a tap before navigation end abandons the load",
                steps: [.tap(0), .navStart("a", 10), .tap(20), .frame(30), .advance(to: 30_000)],
                expected: []
            ),
            Scenario(
                name: "an interrupt abandons a candidate, so the next navigation starts a fresh load",
                steps: [.tap(0), .interrupt, .navStart("home", 10), .navEnd("home", 20), .frame(30)],
                expected: [result(start: 10, duration: 20, name: "home", outcome: .timedOut, navStartDelay: 0, navDuration: 10, firstFrame: 10)]
            ),
            Scenario(
                name: "an interrupt while navigating abandons the load, and its timeout can't end the next load",
                steps: [
                    .tap(0), .navStart("first", 0), .interrupt, .navEnd("first", 10),  // first's timeout was due at t=30000
                    .navStart("second", 100), .navEnd("second", 110),  // second's at t=30100
                    .advance(to: 30_000), .frame(30_050)
                ],
                expected: [
                    result(start: 100, duration: 29_950, name: "second", outcome: .timedOut, navStartDelay: 0, navDuration: 10, firstFrame: 29_940)
                ]
            ),
            Scenario(
                name: "an interrupt while waiting abandons the load, emitting nothing",
                steps: [.tap(0), .navStart("home", 0), .navEnd("home", 10), .interrupt, .frame(20), .advance(to: 30_000)],
                expected: []
            ),
            Scenario(
                name: "a tap abandons a load still navigating, and its timeout can't end the next load",
                steps: [
                    .tap(0), .navStart("first", 0),  // first's timeout is due at t=30000
                    .tap(10), .navStart("second", 20), .navEnd("second", 20),  // second's at t=30010
                    .advance(to: 30_000), .frame(30_005)
                ],
                expected: [
                    result(start: 10, duration: 29_995, name: "second", outcome: .timedOut, navStartDelay: 10, navDuration: 0, firstFrame: 29_985)
                ]
            )
        ]

        for scenario in scenarios {
            XCTContext.runActivity(named: scenario.name) { _ in
                reset()
                run(scenario.steps)
                assertResults(emitted, scenario.expected, scenario.name)
            }
        }
    }

    // MARK: Mid-sequence

    /// The timeout window runs from the tap, not from the navigation that confirms it.
    func test_timeoutRunsFromTheTap() {
        run([.tap(0), .advance(to: 400)])
        // with no times passed, the inputs are stamped with the current uptime (t=400)
        tracker.navigationStart(name: "home")
        tracker.navigationEnd(name: "home")

        run([.advance(to: 29_999)])
        XCTAssertTrue(emitted.isEmpty, "the tap's window has not elapsed yet")

        run([.advance(to: 30_000)])
        assertResults(emitted, [result(start: 0, duration: 400, name: "home", outcome: .timedOut, navStartDelay: 400, navDuration: 0, firstFrame: 0)])
    }

    /// A load completes as soon as its first frame arrives, without waiting for the timeout.
    func test_firstFrameCompletesImmediately() {
        run([.tap(0), .navStart("home", 10), .navEnd("home", 20)])
        XCTAssertTrue(emitted.isEmpty)

        run([.frame(30)])
        XCTAssertEqual(emitted.count, 1)
    }

    // MARK: Wall clock

    /// The start is converted to wall-clock relative to the current time on both clocks, so a tap
    /// delivered late still reports when it happened.
    func test_startTimeIsConvertedToWallClock() throws {
        let wallNow = Date(timeIntervalSince1970: 1_700_000_000)
        clock.uptime = Self.origin + 0.1
        tracker = makeTracker(dateProvider: { wallNow })

        tracker.tap(at: Self.origin)  // 100ms before now
        tracker.navigationStart(name: "home", at: Self.origin + 0.05)
        tracker.navigationEnd(name: "home", at: Self.origin + 0.06)
        tracker.frame(at: Self.origin + 0.07)

        let startTime = try XCTUnwrap(emitted.first?.startTime)
        XCTAssertEqual(startTime.timeIntervalSince1970, wallNow.timeIntervalSince1970 - 0.1, accuracy: 0.000_001)
    }

    // MARK: Attributes

    func test_attributes() {
        let result = ScreenLoadResult(
            startTime: Date(timeIntervalSince1970: 0),
            durationMs: 40,
            screenName: "home",
            outcome: .userInterrupted,
            navStartDelayMs: 20,
            navDurationMs: 10,
            firstFrameDurationMs: 5,
            idleThresholdMs: 0,
            timeoutMs: 30_000,
            navTimeoutMs: 500
        )

        XCTAssertEqual(
            result.attributes,
            [
                "view.name": "home",
                "screen_load.outcome": "user_interrupted",
                "screen_load.nav_start_delay_ms": "20",
                "screen_load.nav_duration_ms": "10",
                "screen_load.first_frame_duration_ms": "5",
                "screen_load.idle_threshold_ms": "0",
                "screen_load.timeout_ms": "30000",
                "screen_load.nav_timeout_ms": "500"
            ]
        )
    }

    func test_outcomeWireValues() {
        XCTAssertEqual(ScreenLoadOutcome.settled.wireValue, "settled")
        XCTAssertEqual(ScreenLoadOutcome.timedOut.wireValue, "timed_out")
        XCTAssertEqual(ScreenLoadOutcome.userInterrupted.wireValue, "user_interrupted")
        XCTAssertEqual(ScreenLoadOutcome.navigationInterrupted.wireValue, "navigation_interrupted")
    }

    // MARK: Helpers

    private func makeTracker(dateProvider: (() -> Date)? = nil) -> ScreenLoadTracker {
        let clock = clock!
        return ScreenLoadTracker(
            queue: .main,
            uptimeProvider: { clock.uptime },
            // wall clock tracks uptime, so a load's start time can be asserted against its uptime
            dateProvider: dateProvider ?? { Date(timeIntervalSince1970: clock.uptime) },
            scheduleTimeout: { delay, item in clock.schedule(delay, item) },
            emit: { [weak self] in self?.emitted.append($0) }
        )
    }

    private func run(_ steps: [Step]) {
        for step in steps {
            switch step {
            case .tap(let ms):
                tracker.tap(at: advance(to: ms))
            case .navStart(let name, let ms):
                tracker.navigationStart(name: name, at: advance(to: ms))
            case .navEnd(let name, let ms):
                tracker.navigationEnd(name: name, at: advance(to: ms))
            case .frame(let ms):
                tracker.frame(at: advance(to: ms))
            case .interrupt:
                tracker.interrupt()
            case .advance(let ms):
                advance(to: ms)
            }
        }
    }

    /// Moves the clock forward to `ms` (never back), running any timeouts due, and returns `ms` as uptime.
    @discardableResult
    private func advance(to ms: Int) -> TimeInterval {
        let time = Self.uptime(ms)
        clock.advance(to: time)
        return time
    }

    private static func uptime(_ ms: Int) -> TimeInterval {
        origin + TimeInterval(ms) / 1000
    }

    private func result(
        start: Int,
        duration: Int,
        name: String,
        outcome: ScreenLoadOutcome,
        navStartDelay: Int,
        navDuration: Int,
        firstFrame: Int
    ) -> ScreenLoadResult {
        ScreenLoadResult(
            startTime: Date(timeIntervalSince1970: Self.uptime(start)),
            durationMs: duration,
            screenName: name,
            outcome: outcome,
            navStartDelayMs: navStartDelay,
            navDurationMs: navDuration,
            firstFrameDurationMs: firstFrame,
            idleThresholdMs: 0,
            timeoutMs: 30_000,
            navTimeoutMs: 500
        )
    }

    /// Compares results exactly, except the start time, which goes through floating-point clock math.
    private func assertResults(
        _ actual: [ScreenLoadResult],
        _ expected: [ScreenLoadResult],
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, "result count: \(message)", file: file, line: line)
        for (actual, expected) in zip(actual, expected) {
            XCTAssertEqual(
                actual.startTime.timeIntervalSince1970,
                expected.startTime.timeIntervalSince1970,
                accuracy: 0.000_001,
                "start time: \(message)",
                file: file,
                line: line
            )
            let normalized = ScreenLoadResult(
                startTime: expected.startTime,
                durationMs: actual.durationMs,
                screenName: actual.screenName,
                outcome: actual.outcome,
                navStartDelayMs: actual.navStartDelayMs,
                navDurationMs: actual.navDurationMs,
                firstFrameDurationMs: actual.firstFrameDurationMs,
                idleThresholdMs: actual.idleThresholdMs,
                timeoutMs: actual.timeoutMs,
                navTimeoutMs: actual.navTimeoutMs
            )
            XCTAssertEqual(normalized, expected, message, file: file, line: line)
        }
    }
}

/// A manual uptime clock with the timeouts scheduled against it.
private final class ManualClock {
    var uptime: TimeInterval
    private var pending: [(deadline: TimeInterval, item: DispatchWorkItem)] = []

    init(uptime: TimeInterval) {
        self.uptime = uptime
    }

    func schedule(_ delay: TimeInterval, _ item: DispatchWorkItem) {
        pending.append((uptime + delay, item))
    }

    /// Moves forward to `time`, performing each item that falls due in deadline order.
    ///
    /// Cancelled items aren't skipped here: `perform()` itself does nothing for them, so it is the
    /// tracker's cancellation of a stale timeout that's under test. Deadlines within a microsecond
    /// count as due, so floating-point drift can't hold back a timeout due exactly at `time`.
    func advance(to time: TimeInterval) {
        while let next = pending.enumerated().filter({ $0.element.deadline <= time + 0.000_001 }).min(by: { $0.element.deadline < $1.element.deadline }) {
            pending.remove(at: next.offset)
            uptime = max(uptime, next.element.deadline)
            next.element.item.perform()
        }
        uptime = max(uptime, time)
    }
}
