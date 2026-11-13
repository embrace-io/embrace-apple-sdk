//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Overhead release gate for `SmoothnessCaptureService`. `bin/smoothness_overhead.py` pairs the
/// results by name and applies the pass criteria.
///
/// Hang capture is on in every arm, so the Off/On delta isolates Smoothness. The `OnPlusCost` arm is
/// a positive control: it adds a known per-frame cost the gate must report as over budget.
///
/// XCTest runs methods alphabetically, so the numbering gives a mirrored order (Off, On, OnPlusCost,
/// OnPlusCost, On, Off) and device drift over the run cancels out of every comparison.
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
        case onPlusCost

        var smoothness: Bool { self != .off }
        var injectsCost: Bool { self == .onPlusCost }
    }

    private let animationWindow: TimeInterval = 10

    /// Each arm runs two blocks.
    private let scrollingIterationsPerBlock = 10
    private let animationIterationsPerBlock = 6

    /// About 250× the SDK's ~1µs per-tick budget. Much more would break every frame of the loaded screen.
    private let scrollingControlCostMicros = 250

    /// 6 points of CPU at 120Hz and 3 at 60Hz, so it's over the 1 point budget at either rate.
    private let animationControlCostMicros = 500

    @MainActor
    private func launch(screen: String, arm: Arm, controlCostMicros: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EMBBenchmarkScreen"] = screen
        app.launchEnvironment["EMBHang"] = "1"
        // The scheme attaches a debugger for local runs, which would disable both services.
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

    /// Hitches come from Apple's scroll signposts, independent of the SDK's own frame accounting. CPU
    /// is informational only here, since the frame load confounds it.
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
                LabelMetric(app: app, labels: [.displayRefreshRate, .maxDisplayRate, .smoothnessFrames, .thermalState])
            ],
            options: options
        ) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }

        assertSmoothness(active: arm.smoothness, in: app)
    }

    /// `XCTClockMetric` lets the script turn CPU time into utilization.
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
                LabelMetric(app: app, labels: [.displayRefreshRate, .maxDisplayRate, .smoothnessFrames, .thermalState])
            ],
            options: options
        ) {
            Thread.sleep(forTimeInterval: animationWindow)
        }

        assertSmoothness(active: arm.smoothness, in: app)
    }

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
