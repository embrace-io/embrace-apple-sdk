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

    // MARK: - Touch: host app hitches while dragging

    @MainActor
    func testTouch_1_smoothnessOff() throws {
        measureTouch(.off)
    }

    @MainActor
    func testTouch_2_smoothnessOn() throws {
        measureTouch(.on)
    }

    @MainActor
    func testTouch_3_smoothnessOnPlusCost() throws {
        measureTouch(.onPlusCost)
    }

    @MainActor
    func testTouch_4_smoothnessOnPlusCost() throws {
        measureTouch(.onPlusCost)
    }

    @MainActor
    func testTouch_5_smoothnessOn() throws {
        measureTouch(.on)
    }

    @MainActor
    func testTouch_6_smoothnessOff() throws {
        measureTouch(.off)
    }

    // MARK: - Idle: steady-state CPU with nothing to draw

    @MainActor
    func testIdle_1_smoothnessOff() throws {
        measureIdle(.off)
    }

    @MainActor
    func testIdle_2_smoothnessOn() throws {
        measureIdle(.on)
    }

    @MainActor
    func testIdle_3_smoothnessOnPlusCost() throws {
        measureIdle(.onPlusCost)
    }

    @MainActor
    func testIdle_4_smoothnessOnPlusCost() throws {
        measureIdle(.onPlusCost)
    }

    @MainActor
    func testIdle_5_smoothnessOn() throws {
        measureIdle(.on)
    }

    @MainActor
    func testIdle_6_smoothnessOff() throws {
        measureIdle(.off)
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
    private let touchIterationsPerBlock = 10
    private let animationIterationsPerBlock = 6

    /// About 250× the SDK's ~1µs per-tick budget. Much more would break every frame of the loaded screens.
    private let loadedControlCostMicros = 250

    /// 6 points of CPU at 120Hz and 3 at 60Hz, so it's over the 1 point budget at either rate.
    private let unloadedControlCostMicros = 500

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
        let app = launch(screen: "smoothness-scroll", arm: arm, controlCostMicros: loadedControlCostMicros)
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
        let app = launch(screen: "smoothness-animation", arm: arm, controlCostMicros: unloadedControlCostMicros)
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

    /// Like scrolling, but the run loop never tracks, so touches and redraws drive focal moments.
    @MainActor
    private func measureTouch(_ arm: Arm) {
        let app = launch(screen: "smoothness-touch", arm: arm, controlCostMicros: loadedControlCostMicros)
        let surface = app.descendants(matching: .any)["smoothness-touch"]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        app.settleBenchmarkScreen(smoothness: arm.smoothness) {
            surface.benchmarkDrag()
            surface.benchmarkDrag(reversed: true)
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = touchIterationsPerBlock

        measure(
            metrics: [
                XCTOSSignpostMetric.benchmarkDragMetric,
                XCTCPUMetric(application: app),
                XCTClockMetric(),
                LabelMetric(app: app, labels: [.displayRefreshRate, .maxDisplayRate, .smoothnessFrames, .thermalState])
            ],
            options: options
        ) {
            surface.benchmarkDrag()
            stopMeasuring()
            surface.benchmarkDrag(reversed: true)
        }

        assertSmoothness(active: arm.smoothness, in: app)
    }

    /// Like animation, but nothing draws, so the On arm's extra CPU includes the SDK's display link
    /// waking a sleeping main thread.
    @MainActor
    private func measureIdle(_ arm: Arm) {
        let app = launch(screen: "smoothness-idle", arm: arm, controlCostMicros: unloadedControlCostMicros)
        XCTAssertTrue(app.descendants(matching: .any)["smoothness-idle"].waitForExistence(timeout: 10))
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

    /// Focal moments must be tracked too, or touch and fling wouldn't measure their observers.
    @MainActor
    private func assertSmoothness(active: Bool, in app: XCUIApplication) {
        let frames = Int(app.staticTexts["smoothness-frames"].label) ?? 0
        let focalMoments = app.staticTexts["focal-moments"].label
        if active {
            XCTAssertGreaterThan(frames, 0, "SmoothnessCaptureService counted no frames, so it wasn't running")
            XCTAssertEqual(focalMoments, "1", "SmoothnessCaptureService isn't tracking focal moments")
        } else {
            XCTAssertEqual(frames, 0, "SmoothnessCaptureService counted frames in the Off arm")
            XCTAssertEqual(focalMoments, "0", "SmoothnessCaptureService tracked focal moments in the Off arm")
        }
    }
}
