//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Overhead release gate for `SmoothnessCaptureService`.
///
/// Each scenario compares `_smoothnessOff` and `_smoothnessOn` arms against the same build, with
/// `HangCaptureService` on in both, so the delta isolates Smoothness. `bin/smoothness_overhead.py`
/// pairs the results by name and applies the pass criteria.
///
/// Both services disable themselves under a debugger, which the scheme attaches for a local run, so
/// every arm sets `EMBAllowWatchdogInDebugger=1`. Each arm also reports and asserts the SDK's frame
/// count, so an On arm where Smoothness never ran can't pass as a measurement.
///
/// Each scenario also runs a positive control, `_smoothnessOnPlusCost`: the On arm plus a fixed
/// amount of main-thread work on every frame (`scrollingControlCostMicros`,
/// `animationControlCostMicros`). The script requires every gate to report it as over budget, which
/// proves the gate can see a cost of that size at all.
///
/// XCTest runs methods alphabetically, and the device drifts over a run (it warms up, may throttle,
/// background work settles). So each arm runs as two blocks in a mirrored order, numbered so the
/// alphabetical order is Off, On, OnPlusCost, OnPlusCost, On, Off. Every arm's average position is
/// the same, so a steady drift cancels out of every comparison. The script merges each arm's blocks.
/// Every iteration also records the thermal state, and the script rejects a throttled run.
///
/// Every arm settles before measuring (`settleBenchmarkScreen`), so the SDK's startup work doesn't
/// overlap the first iterations.
final class SmoothnessOverheadUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Scrolling: host app hitches

    @MainActor
    func testScrolling_1_smoothnessOff() throws {
        measureScrolling(.off)
    }

    @MainActor
    func testScrolling_2_smoothnessOn() throws {
        measureScrolling(.on)
    }

    @MainActor
    func testScrolling_3_smoothnessOnPlusCost() throws {
        measureScrolling(.onPlusCost)
    }

    @MainActor
    func testScrolling_4_smoothnessOnPlusCost() throws {
        measureScrolling(.onPlusCost)
    }

    @MainActor
    func testScrolling_5_smoothnessOn() throws {
        measureScrolling(.on)
    }

    @MainActor
    func testScrolling_6_smoothnessOff() throws {
        measureScrolling(.off)
    }

    // MARK: - Continuous animation: steady-state CPU

    @MainActor
    func testAnimation_1_smoothnessOff() throws {
        measureAnimation(.off)
    }

    @MainActor
    func testAnimation_2_smoothnessOn() throws {
        measureAnimation(.on)
    }

    @MainActor
    func testAnimation_3_smoothnessOnPlusCost() throws {
        measureAnimation(.onPlusCost)
    }

    @MainActor
    func testAnimation_4_smoothnessOnPlusCost() throws {
        measureAnimation(.onPlusCost)
    }

    @MainActor
    func testAnimation_5_smoothnessOn() throws {
        measureAnimation(.on)
    }

    @MainActor
    func testAnimation_6_smoothnessOff() throws {
        measureAnimation(.off)
    }

    // MARK: - Private

    private enum Arm {
        case off
        case on
        /// The positive control.
        case onPlusCost

        var smoothness: Bool { self != .off }
        var injectsCost: Bool { self == .onPlusCost }
    }

    private let animationWindow: TimeInterval = 10

    /// Iterations per block; each arm runs two blocks, so twice this many per arm. Each animation
    /// iteration is a 10s window.
    private let scrollingIterationsPerBlock = 10
    private let animationIterationsPerBlock = 6

    /// The scroll control's added cost per frame, about 250× the SDK's ~1µs on-device per-tick
    /// budget. It's gated on hitches, and a larger cost would only break every frame of the loaded
    /// screen.
    private let scrollingControlCostMicros = 250

    /// The animation control's added cost per frame. It's gated on CPU, against a 1 point budget:
    /// 500µs is 6 points at 120Hz and 3 at 60Hz, enough margin for the control to be proven over
    /// budget at either rate. The screen has no frame load, so the cost breaks nothing.
    private let animationControlCostMicros = 500

    @MainActor
    private func launch(screen: String, arm: Arm, controlCostMicros: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EMBBenchmarkScreen"] = screen
        app.launchEnvironment["EMBHang"] = "1"
        app.launchEnvironment["EMBAllowWatchdogInDebugger"] = "1"
        if arm.smoothness {
            app.launchEnvironment["EMBSmoothness"] = "1"
        }
        if arm.injectsCost {
            app.launchEnvironment["EMBInjectedTickCostMicros"] = String(controlCostMicros)
        }
        app.launch()
        return app
    }

    /// Uses Apple's scroll signposts, so hitches are measured independently of the SDK's own
    /// frame accounting. `XCTClockMetric` records each swipe's window so CPU utilization can be
    /// reported, for information only: the frame load confounds it.
    @MainActor
    private func measureScrolling(_ arm: Arm) {
        let app = launch(screen: "smoothness-scroll", arm: arm, controlCostMicros: scrollingControlCostMicros)
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        app.settleBenchmarkScreen(smoothness: arm.smoothness) {
            list.swipeUp(velocity: .fast)
            list.swipeDown(velocity: .fast)
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = scrollingIterationsPerBlock

        measure(
            metrics: [
                XCTOSSignpostMetric.scrollingAndDecelerationMetric,
                XCTCPUMetric(application: app),
                XCTClockMetric(),
                LabelMetric(app: app, labels: [.displayLinkRate, .displayRefreshRate, .maxDisplayRate, .smoothnessFrames, .thermalState])
            ],
            options: options
        ) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }

        assertSmoothness(active: arm.smoothness, in: app)
    }

    /// Measures a fixed idle window while the screen animates every frame. `XCTClockMetric` records
    /// the window so CPU time can be turned into utilization.
    @MainActor
    private func measureAnimation(_ arm: Arm) {
        let app = launch(screen: "smoothness-animation", arm: arm, controlCostMicros: animationControlCostMicros)
        XCTAssertTrue(app.otherElements["smoothness-animation"].waitForExistence(timeout: 10))
        app.settleBenchmarkScreen(smoothness: arm.smoothness)

        let options = XCTMeasureOptions()
        options.iterationCount = animationIterationsPerBlock

        measure(
            metrics: [
                XCTCPUMetric(application: app),
                XCTClockMetric(),
                LabelMetric(app: app, labels: [.displayLinkRate, .displayRefreshRate, .maxDisplayRate, .smoothnessFrames, .thermalState])
            ],
            options: options
        ) {
            Thread.sleep(forTimeInterval: animationWindow)
        }

        assertSmoothness(active: arm.smoothness, in: app)
    }

    /// Fails the run if Smoothness wasn't counting frames in the On arm, or was in the Off arm.
    @MainActor
    private func assertSmoothness(active: Bool, in app: XCUIApplication) {
        let frames = Int(app.staticTexts["smoothness-frames"].label) ?? 0
        if active {
            XCTAssertGreaterThan(frames, 0, "SmoothnessCaptureService counted no frames, so it wasn't running")
        } else {
            XCTAssertEqual(frames, 0, "SmoothnessCaptureService counted frames in the Off arm")
        }
    }
}

extension XCUIApplication {

    /// The least time between a benchmark screen appearing and its first measured iteration.
    static let benchmarkSettleTime: TimeInterval = 5

    /// Waits for a benchmark screen to settle before measuring. Shared with
    /// `SmoothnessLoadCalibrationUITests`.
    ///
    /// The SDK starts in the app's `init`, but its startup work (session start, storage, config
    /// fetch, upload) carries on in the background after launch. Measuring straight away overlaps it
    /// with the first iterations, which adds noise, and more of it in arms that start more services.
    ///
    /// Waits until the screen reports its refresh rate, and, if `smoothness`, until the SDK has
    /// counted frames. Then runs `warmUp`, and sleeps out the rest of `benchmarkSettleTime`.
    @MainActor
    func settleBenchmarkScreen(smoothness: Bool, warmUp: () -> Void = {}) {
        let deadline = Date().addingTimeInterval(Self.benchmarkSettleTime)

        waitForNonZeroLabel("display-refresh-rate", "The benchmark screen never reported a refresh rate")
        if smoothness {
            waitForNonZeroLabel("smoothness-frames", "SmoothnessCaptureService counted no frames before measuring, so it isn't running")
        }
        warmUp()

        let remaining = deadline.timeIntervalSinceNow
        if remaining > 0 {
            Thread.sleep(forTimeInterval: remaining)
        }
    }

    /// Fails unless the static text `identifier` shows a non-zero number within 10s. The labels
    /// start at "0" and update once a second.
    @MainActor
    private func waitForNonZeroLabel(_ identifier: String, _ message: String) {
        let predicate = NSPredicate(format: "label != %@ AND label != %@", "0", "0.0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: staticTexts[identifier])
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, message)
    }
}

/// Reports the benchmark screen's numeric static texts, read when each iteration stops, as one
/// measurement each. Shared with `SmoothnessLoadCalibrationUITests`.
///
/// One metric reads all its labels, one after another. XCTest stops metrics concurrently, and every
/// element query records an XCTest activity, so with one metric per label two queries could
/// overlap, and XCTest aborted the test runner ("… StaticText must be the top of the stack").
final class LabelMetric: NSObject, XCTMetric {

    struct Label {
        /// The static text's accessibility identifier on the benchmark screen.
        let label: String
        let identifier: String
        let displayName: String
        let unitSymbol: String
    }

    private let app: XCUIApplication
    private let labels: [Label]
    private var values: [Double] = []

    init(app: XCUIApplication, labels: [Label]) {
        self.app = app
        self.labels = labels
    }

    func copy(with zone: NSZone? = nil) -> Any {
        LabelMetric(app: app, labels: labels)
    }

    func didStopMeasuring() {
        values = labels.map { Double(app.staticTexts[$0.label].label) ?? 0 }
    }

    func reportMeasurements(
        from startTime: XCTPerformanceMeasurementTimestamp,
        to endTime: XCTPerformanceMeasurementTimestamp
    ) throws -> [XCTPerformanceMeasurement] {
        zip(labels, values).map { label, value in
            XCTPerformanceMeasurement(
                identifier: label.identifier,
                displayName: label.displayName,
                doubleValue: value,
                unitSymbol: label.unitSymbol
            )
        }
    }
}

extension LabelMetric.Label {

    /// Callbacks per second over the last second, for a display link configured like the SDK's.
    /// Drops when the main thread hitches, so it's context only.
    static let displayLinkRate = LabelMetric.Label(
        label: "display-link-rate",
        identifier: "io.embrace.benchmarks.displayLinkRate",
        displayName: "Display Link Rate",
        unitSymbol: "Hz"
    )

    /// The display's refresh rate over the last second, from frame durations, so hitches don't
    /// lower it. The script requires it to reach the device's maximum in every arm.
    static let displayRefreshRate = LabelMetric.Label(
        label: "display-refresh-rate",
        identifier: "io.embrace.benchmarks.displayRefreshRate",
        displayName: "Display Refresh Rate",
        unitSymbol: "Hz"
    )

    /// The screen's `maximumFramesPerSecond`: what the refresh rate is checked against.
    static let maxDisplayRate = LabelMetric.Label(
        label: "max-display-rate",
        identifier: "io.embrace.benchmarks.maxDisplayRate",
        displayName: "Max Display Rate",
        unitSymbol: "Hz"
    )

    /// Frames the SDK counted in the open foreground part. Proves whether Smoothness was running:
    /// `bin/smoothness_overhead.py` requires it to be above 0 in the On arm and 0 in the Off arm.
    static let smoothnessFrames = LabelMetric.Label(
        label: "smoothness-frames",
        identifier: "io.embrace.benchmarks.smoothnessFrames",
        displayName: "Smoothness Frames",
        unitSymbol: "frames"
    )

    /// `ProcessInfo.ThermalState` as its raw value: 0 nominal, 1 fair, 2 serious, 3 critical. The
    /// script rejects a run that reaches serious, since throttling invalidates the comparison.
    static let thermalState = LabelMetric.Label(
        label: "thermal-state",
        identifier: "io.embrace.benchmarks.thermalState",
        displayName: "Thermal State",
        unitSymbol: "state"
    )
}
