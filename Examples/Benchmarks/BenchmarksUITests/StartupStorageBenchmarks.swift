//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

/// Measures the main-thread time spent in `Embrace.setup()` and `Embrace.start()`
/// with different amounts of metadata already in the SDK's storage.
final class StartupStorageBenchmarks: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var metrics: [XCTMetric] {
        [
            XCTOSSignpostMetric(subsystem: "io.embrace.benchmarks", category: "startup", name: "setup"),
            XCTOSSignpostMetric(subsystem: "io.embrace.benchmarks", category: "startup", name: "start")
        ]
    }

    private func measureStartup(seedCount: Int) {
        let app = XCUIApplication()
        app.launchEnvironment["EMBSeedMetadataCount"] = String(seedCount)

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: metrics, options: options) {
            app.launch()
            app.terminate()
        }
    }

    @MainActor
    func testStartup_emptyMetadata() {
        measureStartup(seedCount: 0)
    }

    @MainActor
    func testStartup_10kMetadata() {
        measureStartup(seedCount: 10_000)
    }

    @MainActor
    func testStartup_50kMetadata() {
        measureStartup(seedCount: 50_000)
    }
}
