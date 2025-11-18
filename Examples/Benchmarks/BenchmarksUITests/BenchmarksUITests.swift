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
    func testLaunchUntilResponsivePerformance() throws {
        let app = XCUIApplication()
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            app.launch()
        }
    }

    private func metrics(for app: XCUIApplication) -> [XCTMetric] {
        [
            XCTStorageMetric(application: app),
            XCTMemoryMetric(application: app)
        ]
    }

    @MainActor
    func testSpanEventsEfficiency() throws {
        let app = XCUIApplication()
        app.launchEnvironment["EMBUseNewStorageForEvents"] = "1"
        app.launchEnvironment["EMBIgnoreBreadcrumbLimits"] = "1"

        app.launch()
        let button = app.buttons["logical-writes-test-button"]
        measure(metrics: metrics(for: app)) {
            button.tap()
        }
    }
}
