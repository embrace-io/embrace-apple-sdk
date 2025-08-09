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
        app.launch()

        let initButton = app.buttons["EmbraceInitButton"]
        XCTAssertTrue(initButton.waitForExistence(timeout: 5))
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        XCTAssertTrue(sideMenuButton.waitForExistence(timeout: 5))
        sideMenuButton.tap()

        let testScreenButton = app.staticTexts["viewController"]
        XCTAssertTrue(testScreenButton.waitForExistence(timeout: 5))
        testScreenButton.tap()

        continueAfterFailure = true
    }

    override func tearDownWithError() throws {

    }

    func testViewDidLoad() {
        let button = app.buttons["viewDidLoadCaptureTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        evaluateTestResults(app)
    }

    func testViewAppearingCycleMeasurement() {
        let button = app.buttons["viewDidAppearMeasurementCaptureTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        evaluateTestResults(app)
    }
}
