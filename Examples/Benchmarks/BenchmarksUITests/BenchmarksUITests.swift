//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

final class BenchmarksUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    @MainActor
    func testLaunchPerformanceNoop() throws {
        let app = XCUIApplication()
        app.launchEnvironment["noop"] = "true"
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
