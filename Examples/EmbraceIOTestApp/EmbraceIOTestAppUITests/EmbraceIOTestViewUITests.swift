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
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["viewController"].tap()

        continueAfterFailure = true
    }

    override func tearDownWithError() throws {

    }

    func testViewDidLoad() {
        app.buttons["viewDidLoadCaptureTestButton"].tap()

        sleep(5)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testViewAppearingCycleMeasurement() {
        app.buttons["viewDidAppearMeasurementCaptureTestButton"].tap()

        sleep(5)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }
}
