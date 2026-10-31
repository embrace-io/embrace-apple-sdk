//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

extension XCUIApplication {

    static let benchmarkSettleTime: TimeInterval = 5

    /// Waits out the SDK's background startup work (session start, storage, config fetch, upload) so
    /// it doesn't overlap the first iterations.
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

    /// The labels start at "0" and update once a second.
    @MainActor
    private func waitForNonZeroLabel(_ identifier: String, _ message: String) {
        let predicate = NSPredicate(format: "label != %@ AND label != %@", "0", "0.0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: staticTexts[identifier])
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, message)
    }
}

extension XCUIElement {

    /// About 1s per drag across the touch screen, so each one spans many frames.
    static let benchmarkDragVelocity = XCUIGestureVelocity(600)

    /// Drags the touch screen's surface diagonally, top-left to bottom-right, clear of the labels in the
    /// top-trailing corner. `reversed` drags back.
    func benchmarkDrag(reversed: Bool = false) {
        let topLeft = coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25))
        let bottomRight = coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.85))
        let (start, end) = reversed ? (bottomRight, topLeft) : (topLeft, bottomRight)
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: Self.benchmarkDragVelocity, thenHoldForDuration: 0)
    }
}

extension XCTOSSignpostMetric {

    /// Hitches during the touch screen's drags, from its `Drag` animation signpost intervals.
    static let benchmarkDragMetric = XCTOSSignpostMetric(subsystem: "io.embrace.benchmarks", category: "smoothness", name: "Drag")
}

/// Reports the benchmark screen's numeric labels as measurements.
///
/// One metric reads every label: XCTest stops metrics concurrently, and overlapping element queries
/// abort the test runner ("… StaticText must be the top of the stack").
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

    /// Computed from frame durations, so hitches don't lower it.
    static let displayRefreshRate = LabelMetric.Label(
        label: "display-refresh-rate",
        identifier: "io.embrace.benchmarks.displayRefreshRate",
        displayName: "Display Refresh Rate",
        unitSymbol: "Hz"
    )

    /// `maximumFramesPerSecond`, which the script checks the refresh rate against.
    static let maxDisplayRate = LabelMetric.Label(
        label: "max-display-rate",
        identifier: "io.embrace.benchmarks.maxDisplayRate",
        displayName: "Max Display Rate",
        unitSymbol: "Hz"
    )

    /// Frames counted in the open foreground part, proving whether Smoothness was running.
    static let smoothnessFrames = LabelMetric.Label(
        label: "smoothness-frames",
        identifier: "io.embrace.benchmarks.smoothnessFrames",
        displayName: "Smoothness Frames",
        unitSymbol: "frames"
    )

    /// `ProcessInfo.ThermalState.rawValue`. The script rejects a run that reaches serious (2).
    static let thermalState = LabelMetric.Label(
        label: "thermal-state",
        identifier: "io.embrace.benchmarks.thermalState",
        displayName: "Thermal State",
        unitSymbol: "state"
    )
}
