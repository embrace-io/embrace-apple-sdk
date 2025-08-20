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
        continueAfterFailure = true
        app.launchAndOpenTestTab("session")
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(5)
        app.activate()
    }

    private func runSessionSpanTest() {
        let button = app.buttons["finishedSessionPayloadTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    func testSendFinishedSessionSpan() {
        runSessionSpanTest()
        sleep(5)
        backgroundAndReopenApp()
        evaluateTestResults(app)
    }
}
