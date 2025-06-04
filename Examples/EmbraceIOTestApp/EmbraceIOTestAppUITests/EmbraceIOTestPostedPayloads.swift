//
//  EmbraceIOTestPostedPayloads.swift
//  EmbraceIOTestApp
//
//

import XCTest
@testable import EmbraceCommonInternal

final class EmbraceIOTestPostedPayloads: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()

        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertNotNil(initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["uploadedPayloads"].tap()
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(1)
        app.activate()
    }

    private func runSessionSpanTest() -> Bool {
        let enabled = NSPredicate(format:"enabled == true")
        let testButton = app.buttons["sessionPayloadTestButton"]
        let buttonEnabled = expectation(for: enabled, evaluatedWith: testButton, handler: nil)
        wait(for: [buttonEnabled], timeout: 5.0)
        let isEnabled = testButton.isEnabled
        app.buttons["sessionPayloadTestButton"].tap()

        return isEnabled
    }

    private func addPersona() {
        app.buttons["MetadataLifespan_session"].tap()
        app.buttons["SessionTests_Personas_AddButton"].tap()
    }

    func testSendFinishedSessionSpan() {
        sleep(5)
        backgroundAndReopenApp()
        XCTAssertTrue(runSessionSpanTest(), "Test Button wait for enabled timed out")

        evaluateTestResults(app)
    }

    func testSendFinishedSessionSpan_withPersona() {
        addPersona()
        sleep(5)
        backgroundAndReopenApp()
        XCTAssertTrue(runSessionSpanTest(), "Test Button wait for enabled timed out")

        evaluateTestResults(app)
    }
}
