//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Finds the frame load at which `SmoothnessOverheadUITests` is most sensitive to added cost, for each
/// loaded scenario: scrolling (fling) and touch.
///
/// Too little load hides added cost in idle headroom; too much and frames already miss. Each load
/// runs with 0, 25µs and 250µs injected per frame, with Smoothness off and hang capture on as in the
/// gate. `bin/smoothness_calibration.py` reports the results per scenario.
///
/// Not part of the gate: only the manual **Smoothness Load Calibration** workflow runs this class.
final class SmoothnessLoadCalibrationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Scrolling Fraction60

    @MainActor
    func testScrollingFraction60_1_off() {
        scroll(loadFraction: 0.60, .off)
    }

    @MainActor
    func testScrollingFraction60_2_cost25() {
        scroll(loadFraction: 0.60, .cost25)
    }

    @MainActor
    func testScrollingFraction60_3_cost250() {
        scroll(loadFraction: 0.60, .cost250)
    }

    // MARK: - Scrolling Fraction75

    @MainActor
    func testScrollingFraction75_1_off() {
        scroll(loadFraction: 0.75, .off)
    }

    @MainActor
    func testScrollingFraction75_2_cost25() {
        scroll(loadFraction: 0.75, .cost25)
    }

    @MainActor
    func testScrollingFraction75_3_cost250() {
        scroll(loadFraction: 0.75, .cost250)
    }

    // MARK: - Scrolling Fraction90

    @MainActor
    func testScrollingFraction90_1_off() {
        scroll(loadFraction: 0.90, .off)
    }

    @MainActor
    func testScrollingFraction90_2_cost25() {
        scroll(loadFraction: 0.90, .cost25)
    }

    @MainActor
    func testScrollingFraction90_3_cost250() {
        scroll(loadFraction: 0.90, .cost250)
    }

    // MARK: - Touch Fraction60

    @MainActor
    func testTouchFraction60_1_off() {
        touch(loadFraction: 0.60, .off)
    }

    @MainActor
    func testTouchFraction60_2_cost25() {
        touch(loadFraction: 0.60, .cost25)
    }

    @MainActor
    func testTouchFraction60_3_cost250() {
        touch(loadFraction: 0.60, .cost250)
    }

    // MARK: - Touch Fraction75

    @MainActor
    func testTouchFraction75_1_off() {
        touch(loadFraction: 0.75, .off)
    }

    @MainActor
    func testTouchFraction75_2_cost25() {
        touch(loadFraction: 0.75, .cost25)
    }

    @MainActor
    func testTouchFraction75_3_cost250() {
        touch(loadFraction: 0.75, .cost250)
    }

    // MARK: - Touch Fraction90

    @MainActor
    func testTouchFraction90_1_off() {
        touch(loadFraction: 0.90, .off)
    }

    @MainActor
    func testTouchFraction90_2_cost25() {
        touch(loadFraction: 0.90, .cost25)
    }

    @MainActor
    func testTouchFraction90_3_cost250() {
        touch(loadFraction: 0.90, .cost250)
    }

    // MARK: - Private

    /// Injected cost per tick, in µs.
    private enum Arm: Int {
        case off = 0
        case cost25 = 25
        case cost250 = 250
    }

    /// Matches a gate arm, so the results predict the gate's verdict.
    private let iterationCount = 20

    @MainActor
    private func launch(screen: String, loadFraction: Double, _ arm: Arm) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EMBBenchmarkScreen"] = screen
        app.launchEnvironment["EMBHang"] = "1"
        app.launchEnvironment["EMBAllowWatchdogInDebugger"] = "1"
        app.launchEnvironment["EMBFrameLoadFraction"] = String(loadFraction)
        if arm != .off {
            app.launchEnvironment["EMBInjectedTickCostMicros"] = String(arm.rawValue)
        }
        app.launch()
        return app
    }

    @MainActor
    private func scroll(loadFraction: Double, _ arm: Arm) {
        let app = launch(screen: "smoothness-scroll", loadFraction: loadFraction, arm)
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        app.settleBenchmarkScreen(smoothness: false) {
            list.swipeUp(velocity: .fast)
            list.swipeDown(velocity: .fast)
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = iterationCount

        measure(
            metrics: [
                XCTOSSignpostMetric.scrollingAndDecelerationMetric,
                LabelMetric(app: app, labels: [.displayRefreshRate, .maxDisplayRate, .thermalState])
            ],
            options: options
        ) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }
    }

    @MainActor
    private func touch(loadFraction: Double, _ arm: Arm) {
        let app = launch(screen: "smoothness-touch", loadFraction: loadFraction, arm)
        let surface = app.descendants(matching: .any)["smoothness-touch"]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        app.settleBenchmarkScreen(smoothness: false) {
            surface.benchmarkDrag()
            surface.benchmarkDrag(reversed: true)
        }

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = iterationCount

        measure(
            metrics: [
                XCTOSSignpostMetric.benchmarkDragMetric,
                LabelMetric(app: app, labels: [.displayRefreshRate, .maxDisplayRate, .thermalState])
            ],
            options: options
        ) {
            surface.benchmarkDrag()
            stopMeasuring()
            surface.benchmarkDrag(reversed: true)
        }
    }
}
