//
//  EmbraceIOTestViewUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest

@testable import EmbraceCommonInternal

final class EmbraceIOTestViewUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchAndOpenTestTab("viewController")
    }

    override func tearDownWithError() throws {

    }

    func testViewDidLoad() {
        let button = app.buttons["viewDidLoadCaptureTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()

        evaluateTestResults(app)
    }

    func testViewAppearingCycleMeasurement() {
        let button = app.buttons["viewDidAppearMeasurementCaptureTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()

        evaluateTestResults(app)
    }
}
