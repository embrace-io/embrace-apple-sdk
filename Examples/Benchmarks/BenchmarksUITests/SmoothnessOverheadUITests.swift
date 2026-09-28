//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Overhead release gate for `SmoothnessCaptureService`.
///
/// Each scenario runs as a `_smoothnessOff` / `_smoothnessOn` pair against the same build, with
/// `HangCaptureService` on in both, so the delta isolates Smoothness. `bin/smoothness_overhead.py`
/// pairs the results by name and applies the pass criteria.
final class SmoothnessOverheadUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Scrolling: host app hitches

    @MainActor
    func testScrolling_smoothnessOff() throws {
        measureScrolling(smoothness: false)
    }

    @MainActor
    func testScrolling_smoothnessOn() throws {
        measureScrolling(smoothness: true)
    }

    // MARK: - Continuous animation: steady-state CPU

    @MainActor
    func testAnimation_smoothnessOff() throws {
        measureAnimation(smoothness: false)
    }

    @MainActor
    func testAnimation_smoothnessOn() throws {
        measureAnimation(smoothness: true)
    }

    // MARK: - Private

    private let animationWindow: TimeInterval = 10

    @MainActor
    private func launch(screen: String, smoothness: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EMBBenchmarkScreen"] = screen
        app.launchEnvironment["EMBHang"] = "1"
        if smoothness {
            app.launchEnvironment["EMBSmoothness"] = "1"
        }
        app.launch()
        return app
    }

    /// Uses Apple's scroll signposts, so hitches are measured independently of the SDK's own
    /// frame accounting.
    @MainActor
    private func measureScrolling(smoothness: Bool) {
        let app = launch(screen: "smoothness-scroll", smoothness: smoothness)
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        // The loaded baseline hitches, which is noisier than a baseline that never does.
        options.iterationCount = 20

        measure(
            metrics: [
                XCTOSSignpostMetric.scrollingAndDecelerationMetric,
                XCTCPUMetric(application: app),
                DisplayLinkRateMetric(app: app)
            ],
            options: options
        ) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }
    }

    /// Measures a fixed idle window while the screen animates every frame. `XCTClockMetric` records
    /// the window so CPU time can be turned into utilization.
    @MainActor
    private func measureAnimation(smoothness: Bool) {
        let app = launch(screen: "smoothness-animation", smoothness: smoothness)
        XCTAssertTrue(app.otherElements["smoothness-animation"].waitForExistence(timeout: 10))

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(
            metrics: [XCTCPUMetric(application: app), XCTClockMetric(), DisplayLinkRateMetric(app: app)],
            options: options
        ) {
            Thread.sleep(forTimeInterval: animationWindow)
        }
    }
}

/// Reports the rate a display link configured like the SDK's actually ran at, read from the
/// benchmark screen's `display-link-rate` label (its rate over the last second) when each
/// iteration stops. Confirms whether a scenario really ran at 120Hz.
private final class DisplayLinkRateMetric: NSObject, XCTMetric {

    private let app: XCUIApplication
    private var rate: Double = 0

    init(app: XCUIApplication) {
        self.app = app
    }

    func copy(with zone: NSZone? = nil) -> Any {
        DisplayLinkRateMetric(app: app)
    }

    func didStopMeasuring() {
        rate = Double(app.staticTexts["display-link-rate"].label) ?? 0
    }

    func reportMeasurements(
        from startTime: XCTPerformanceMeasurementTimestamp,
        to endTime: XCTPerformanceMeasurementTimestamp
    ) throws -> [XCTPerformanceMeasurement] {
        [
            XCTPerformanceMeasurement(
                identifier: "io.embrace.benchmarks.displayLinkRate",
                displayName: "Display Link Rate",
                doubleValue: rate,
                unitSymbol: "Hz"
            )
        ]
    }
}
