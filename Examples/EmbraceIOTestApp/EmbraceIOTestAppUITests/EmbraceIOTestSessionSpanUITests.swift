//
//  EmbraceIOTestSessionSpanUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest
@testable import EmbraceCommonInternal

final class EmbraceIOTestSessionSpanUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        app.launch()

        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["session"].tap()

        continueAfterFailure = true
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(1)
        app.activate()
    }

    private func runSessionSpanTest() {
        app.buttons["finishedSessionPayloadTestButton"].tap()
    }

    private func evaluateTestResults() {
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testSendFinishedSessionSpan() {
        sleep(3)
        runSessionSpanTest()
        sleep(2)
        backgroundAndReopenApp()
        sleep(5)
        evaluateTestResults()
    }
}
