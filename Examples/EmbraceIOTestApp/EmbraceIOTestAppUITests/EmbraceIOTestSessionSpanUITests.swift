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
        XCTAssertTrue(initButton.waitForExistence(timeout: 5))
        initButton.tap()
        
        XCTAssertNotNil(initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        XCTAssertTrue(sideMenuButton.waitForExistence(timeout: 5))
        sideMenuButton.tap()

        let testScreenButton = app.staticTexts["session"]
        XCTAssertTrue(testScreenButton.waitForExistence(timeout: 5))
        testScreenButton.tap()

        continueAfterFailure = true
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(5)
        app.activate()
    }

    private func runSessionSpanTest() {
        let button = app.buttons["finishedSessionPayloadTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    func testSendFinishedSessionSpan() {
        runSessionSpanTest()
        sleep(5)
        backgroundAndReopenApp()
        evaluateTestResults(app)
    }
}
