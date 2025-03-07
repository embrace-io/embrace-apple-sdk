//
//  EmbraceIOTestAppUITests.swift
//  EmbraceIOTestAppUITests
//
//

import XCTest

final class EmbraceIOTestAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {

    }

    func testInitMetadataStartupPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()
        let startupButton = app.buttons["startupTestButton"]
        XCTAssertTrue(startupButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        startupButton.tap()
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testInitMetadataSetupPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()
        let startupButton = app.buttons["setupTestButton"]
        XCTAssertTrue(startupButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        startupButton.tap()
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testCrashPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["crashes"].tap()
        let crashButton = app.buttons["nullReferenceCrashCaptureTestButton"]
        XCTAssertTrue(crashButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        crashButton.tap()

        sleep(3)

        app.launch()
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        sideMenuButton.tap()

        app.staticTexts["crashes"].tap()

        XCTAssertTrue(crashButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        crashButton.tap()

        sleep(3)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }
}
