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
        XCTAssertTrue(initButton.waitForExistence(timeout: 5))
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        XCTAssertTrue(sideMenuButton.waitForExistence(timeout: 5))
        sideMenuButton.tap()

        let testScreen = app.staticTexts["uploadedPayloads"]
        XCTAssertTrue(testScreen.waitForExistence(timeout: 5))
        testScreen.tap()
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        sleep(5)
        app.activate()
    }

    private func runSessionSpanTest() -> Bool {
        let enabled = NSPredicate(format: "enabled == true")
        let testButton = app.buttons["sessionPayloadTestButton"]

        _ = waitUntilElementIsEnabled(element: testButton, timeout: 20)

        let isEnabled = testButton.isEnabled

        if isEnabled {
            testButton.tap()
        }

        return isEnabled
    }

    private func addPersona() {
        let lifespanButton = app.buttons["MetadataLifespan_session"]
        XCTAssertTrue(lifespanButton.waitForExistence(timeout: 5))
        lifespanButton.tap()

        let personasButton = app.buttons["SessionTests_Personas_AddButton"]
        XCTAssertTrue(personasButton.waitForExistence(timeout: 5))
        personasButton.tap()
    }

    private func addUserInfo() {
        let removeAllButton = app.buttons["SessionTests_UserInfo_RemoveAllButton"]
        XCTAssertTrue(removeAllButton.waitForExistence(timeout: 5))
        removeAllButton.tap()

        // Enter Username
        let usernameTextField = app.textFields["SessionTests_UserInfo_Username"]
        XCTAssertTrue(usernameTextField.waitForExistence(timeout: 5))
        usernameTextField.tap()

        _ = waitUntilElementHasFocus(element: usernameTextField)

        usernameTextField.typeText("TestUsername123")
        usernameTextField.typeText(XCUIKeyboardKey.return.rawValue)

        // Enter Email
        let emailTextField = app.textFields["SessionTests_UserInfo_Email"]
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 5))
        emailTextField.tap()

        _ = waitUntilElementHasFocus(element: emailTextField)

        emailTextField.typeText("Some@Email.com")
        emailTextField.typeText(XCUIKeyboardKey.return.rawValue)

        // Enter User ID
        let identifierTextField = app.textFields["SessionTests_UserInfo_Identifier"]
        XCTAssertTrue(identifierTextField.waitForExistence(timeout: 5))
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
