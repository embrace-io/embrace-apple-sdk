//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Overhead release gate for `SmoothnessCaptureService`.
///
/// Each scenario runs as a `_smoothnessOff` / `_smoothnessOn` pair against the same build, with
/// `HangCaptureService` on in both, so the delta isolates Smoothness. `bin/smoothness_overhead.py`
/// pairs the results by name and applies the pass criteria.
///
/// Both services disable themselves under a debugger, which the scheme attaches for a local run, so
/// both arms set `EMBAllowWatchdogInDebugger=1`. Each arm also reports and asserts the SDK's frame
/// count, so an On arm where Smoothness never ran can't pass as a measurement.
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
        app.launchEnvironment["EMBAllowWatchdogInDebugger"] = "1"
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
                LabelMetric.displayLinkRate(app: app),
                LabelMetric.smoothnessFrames(app: app)
            ],
            options: options
        ) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }

        assertSmoothness(active: smoothness, in: app)
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
            metrics: [
                XCTCPUMetric(application: app),
                XCTClockMetric(),
                LabelMetric.displayLinkRate(app: app),
                LabelMetric.smoothnessFrames(app: app)
            ],
            options: options
        ) {
            Thread.sleep(forTimeInterval: animationWindow)
        }

        assertSmoothness(active: smoothness, in: app)
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

/// Reports a numeric static text on the benchmark screen, read when each iteration stops.
private final class LabelMetric: NSObject, XCTMetric {

    /// The rate a display link configured like the SDK's actually ran at over the last second.
    /// Confirms whether a scenario really ran at 120Hz.
    static func displayLinkRate(app: XCUIApplication) -> LabelMetric {
        LabelMetric(
            app: app,
            label: "display-link-rate",
            identifier: "io.embrace.benchmarks.displayLinkRate",
            displayName: "Display Link Rate",
            unitSymbol: "Hz"
        )
    }

    /// Frames the SDK counted in the open foreground part. Proves whether Smoothness was running:
    /// `bin/smoothness_overhead.py` requires it to be above 0 in the On arm and 0 in the Off arm.
    static func smoothnessFrames(app: XCUIApplication) -> LabelMetric {
        LabelMetric(
            app: app,
            label: "smoothness-frames",
            identifier: "io.embrace.benchmarks.smoothnessFrames",
            displayName: "Smoothness Frames",
            unitSymbol: "frames"
        )
    }

    private let app: XCUIApplication
    private let label: String
    private let identifier: String
    private let displayName: String
    private let unitSymbol: String
    private var value: Double = 0

    private init(app: XCUIApplication, label: String, identifier: String, displayName: String, unitSymbol: String) {
        self.app = app
        self.label = label
        self.identifier = identifier
        self.displayName = displayName
        self.unitSymbol = unitSymbol
    }

    func copy(with zone: NSZone? = nil) -> Any {
        LabelMetric(app: app, label: label, identifier: identifier, displayName: displayName, unitSymbol: unitSymbol)
    }

    func didStopMeasuring() {
        value = Double(app.staticTexts[label].label) ?? 0
    }

    func reportMeasurements(
        from startTime: XCTPerformanceMeasurementTimestamp,
        to endTime: XCTPerformanceMeasurementTimestamp
    ) throws -> [XCTPerformanceMeasurement] {
        [
            XCTPerformanceMeasurement(
                identifier: identifier,
                displayName: displayName,
                doubleValue: value,
                unitSymbol: unitSymbol
            )
        ]
    }
}
