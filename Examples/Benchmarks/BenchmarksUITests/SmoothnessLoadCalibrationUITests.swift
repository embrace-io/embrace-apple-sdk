//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Calibration sweep for the scroll scenario's frame load in `SmoothnessOverheadUITests`.
///
/// The gate is only sensitive while the Off arm hitches a little: with too little load, added SDK
/// cost disappears into idle headroom, and with too much, frames that already miss can't get much
/// worse. This sweep scrolls the same screen at several loads, as a fraction of each frame
/// (`EMBFrameLoadFraction`), each with no added cost and with 25µs and 250µs injected per frame. `bin/smoothness_calibration.py` reports,
/// per load, the Off hitch ratio, how clearly each cost stands out from noise, and what the gate
/// would say about it.
///
/// Smoothness is off in every arm, so only the injected cost differs. Hang capture is on, as in the
/// gate. Each arm runs as many iterations as a gate arm, so a verdict here predicts the gate's.
///
/// Not part of the gate: normal benchmark runs skip this class, and the manual **Smoothness Load
/// Calibration** workflow runs only this class. Within a load the arms run in a fixed order (Off
/// first), so a drift over those minutes affects every load the same way and doesn't change which
/// load ranks best.
final class SmoothnessLoadCalibrationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Fraction60

    @MainActor
    func testFraction60_1_off() throws {
        scroll(.fraction(0.60), .off)
    }

    @MainActor
    func testFraction60_2_cost25() throws {
        scroll(.fraction(0.60), .cost25)
    }

    @MainActor
    func testFraction60_3_cost250() throws {
        scroll(.fraction(0.60), .cost250)
    }

    // MARK: - Fraction75

    @MainActor
    func testFraction75_1_off() throws {
        scroll(.fraction(0.75), .off)
    }

    @MainActor
    func testFraction75_2_cost25() throws {
        scroll(.fraction(0.75), .cost25)
    }

    @MainActor
    func testFraction75_3_cost250() throws {
        scroll(.fraction(0.75), .cost250)
    }

    // MARK: - Fraction90

    @MainActor
    func testFraction90_1_off() throws {
        scroll(.fraction(0.90), .off)
    }

    @MainActor
    func testFraction90_2_cost25() throws {
        scroll(.fraction(0.90), .cost25)
    }

    @MainActor
    func testFraction90_3_cost250() throws {
        scroll(.fraction(0.90), .cost250)
    }

    // MARK: - Private

    private enum Load {
        case fraction(Double)
    }

    private enum Arm {
        case off
        case cost25
        case cost250

        var injectedTickCostMicros: Int {
            switch self {
            case .off: return 0
            case .cost25: return 25
            case .cost250: return 250
            }
        }
    }

    /// Matches a gate arm (two blocks of 10), so the calibration predicts the gate's verdict.
    private let iterationCount = 20

    @MainActor
    private func scroll(_ load: Load, _ arm: Arm) {
        let app = XCUIApplication()
        app.launchEnvironment["EMBBenchmarkScreen"] = "smoothness-scroll"
        app.launchEnvironment["EMBHang"] = "1"
        app.launchEnvironment["EMBAllowWatchdogInDebugger"] = "1"
        switch load {
        case .fraction(let fraction):
            app.launchEnvironment["EMBFrameLoadFraction"] = String(fraction)
        }
        if arm.injectedTickCostMicros > 0 {
            app.launchEnvironment["EMBInjectedTickCostMicros"] = String(arm.injectedTickCostMicros)
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
