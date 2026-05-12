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
        app.launchAndOpenTestTab("uploadedPayloads")
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(5)
        app.activate()
    }

    private func runSessionSpanTest() -> Bool {
        let testButton = app.buttons["sessionPayloadTestButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(testButton))

        _ = waitUntilElementIsEnabled(element: testButton, timeout: 20)

        let isEnabled = testButton.isEnabled

        if isEnabled {
            testButton.tap()
        }

        return isEnabled
    }

    private func addPersona() {
        let lifespanButton = app.buttons["MetadataLifespan_session"]
        XCTAssertTrue(lifespanButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(lifespanButton))
        lifespanButton.tap()

        let personasButton = app.buttons["SessionTests_Personas_AddButton"]
        XCTAssertTrue(personasButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(personasButton))
        personasButton.tap()
    }

    private func addUserInfo() {
        let removeAllButton = app.buttons["SessionTests_UserInfo_RemoveAllButton"]
        XCTAssertTrue(removeAllButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(removeAllButton))
        removeAllButton.tap()

        // Enter User ID
        let identifierTextField = app.textFields["SessionTests_UserInfo_Identifier"]
        XCTAssertTrue(identifierTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(identifierTextField))
        identifierTextField.tap()

        _ = waitUntilElementHasFocus(element: identifierTextField)

        identifierTextField.typeText("ABCD1234")
        identifierTextField.typeText(XCUIKeyboardKey.return.rawValue)
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

    func testSendFinishedSessionSpan_withUserInfo() {
        addUserInfo()
        sleep(5)
        backgroundAndReopenApp()
        XCTAssertTrue(runSessionSpanTest(), "Test Button wait for enabled timed out")

        evaluateTestResults(app)
    }
}
