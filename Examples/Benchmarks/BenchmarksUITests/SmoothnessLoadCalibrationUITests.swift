//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Finds the scroll load at which `SmoothnessOverheadUITests` is most sensitive to added cost.
///
/// Too little load hides added cost in idle headroom; too much and frames already miss. Each load
/// runs with 0, 25µs and 250µs injected per frame, with Smoothness off and hang capture on as in the
/// gate. `bin/smoothness_calibration.py` reports the results.
///
/// Not part of the gate: only the manual **Smoothness Load Calibration** workflow runs this class.
final class SmoothnessLoadCalibrationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Fraction60

    @MainActor
    func testFraction60_1_off() {
        scroll(loadFraction: 0.60, .off)
    }

    @MainActor
    func testFraction60_2_cost25() {
        scroll(loadFraction: 0.60, .cost25)
    }

    @MainActor
    func testFraction60_3_cost250() {
        scroll(loadFraction: 0.60, .cost250)
    }

    // MARK: - Fraction75

    @MainActor
    func testFraction75_1_off() {
        scroll(loadFraction: 0.75, .off)
    }

    @MainActor
    func testFraction75_2_cost25() {
        scroll(loadFraction: 0.75, .cost25)
    }

    @MainActor
    func testFraction75_3_cost250() {
        scroll(loadFraction: 0.75, .cost250)
    }

    // MARK: - Fraction90

    @MainActor
    func testFraction90_1_off() {
        scroll(loadFraction: 0.90, .off)
    }

    @MainActor
    func testFraction90_2_cost25() {
        scroll(loadFraction: 0.90, .cost25)
    }

    @MainActor
    func testFraction90_3_cost250() {
        scroll(loadFraction: 0.90, .cost250)
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
    private func scroll(loadFraction: Double, _ arm: Arm) {
        let app = XCUIApplication()
        app.launchEnvironment["EMBBenchmarkScreen"] = "smoothness-scroll"
        app.launchEnvironment["EMBHang"] = "1"
        app.launchEnvironment["EMBAllowWatchdogInDebugger"] = "1"
        app.launchEnvironment["EMBFrameLoadFraction"] = String(loadFraction)
        if arm != .off {
            app.launchEnvironment["EMBInjectedTickCostMicros"] = String(arm.rawValue)
        }
        app.launch()

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
}
