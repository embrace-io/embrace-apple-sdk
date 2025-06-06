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
        sleep(2)
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

    private func addUserInfo() {
        app.buttons["SessionTests_UserInfo_RemoveAllButton"].tap()

        // Enter Username
        let usernameTextField = app.textFields["SessionTests_UserInfo_Username"]
        usernameTextField.tap()

        _ = waitUntilElementHasFocus(element: usernameTextField)

        usernameTextField.typeText("TestUsername123")
        usernameTextField.typeText(XCUIKeyboardKey.return.rawValue)

        // Enter Email
        let emailTextField = app.textFields["SessionTests_UserInfo_Email"]
        emailTextField.tap()

        _ = waitUntilElementHasFocus(element: emailTextField)

        emailTextField.typeText("Some@Email.com")
        emailTextField.typeText(XCUIKeyboardKey.return.rawValue)

        // Enter User ID
        let identifierTextField = app.textFields["SessionTests_UserInfo_Identifier"]
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
