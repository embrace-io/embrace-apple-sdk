//
//  EmbraceIOTestLogsUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest
@testable import EmbraceCommonInternal

final class EmbraceIOTestLogsUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        app.launch()

        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["logging"].tap()

        continueAfterFailure = true
    }

    override func tearDownWithError() throws {

    }

    private func enterCustomMessage() {
        let logMessageTextField = app.textFields["LogTests_LogMessage"]
        logMessageTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageTextField)

        logMessageTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (logMessageTextField.value as? String ?? "").count))

        logMessageTextField.typeText("Some Custom Message")
        logMessageTextField.typeText(XCUIKeyboardKey.return.rawValue)
    }

    private func selectSeverityButton(_ severity: LogSeverity) {
        var identifier: String = ""
        switch severity {
        case .trace:
            identifier = "LogSeverity_Trace"
        case .debug:
            identifier = "LogSeverity_Debug"
        case .info:
            identifier = "LogSeverity_Info"
        case .warn:
            identifier = "LogSeverity_Warn"
        case .error:
            identifier = "LogSeverity_Error"
        case .fatal:
            identifier = "LogSeverity_Fatal"
        }

        app.buttons[identifier].tap()
    }

    private func selectStackTraceBehavior(_ behavior: StackTraceBehavior) {
        var identifier = ""
        switch behavior {
        case .default:
            identifier = "stackTraceBehavior_Default"
        case .notIncluded:
            identifier = "stackTraceBehavior_notIncluded"
        case .custom:
            identifier = "stackTraceBehavior_custom"
        }

        app.buttons[identifier].tap()
    }

    private func runLogTest() {
        app.buttons["logMessageCaptureTestButton"].tap()

        sleep(1)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testLogCapture_trace() {

        enterCustomMessage()

        selectSeverityButton(.trace)

        runLogTest()
    }

    func testLogCapture_debug() {

        enterCustomMessage()

        selectSeverityButton(.debug)

        runLogTest()
    }

    func testLogCapture_info() {

        enterCustomMessage()

        selectSeverityButton(.info)

        runLogTest()
    }

    func testLogCapture_warn() {

        enterCustomMessage()

        selectSeverityButton(.warn)

        runLogTest()
    }

    func testLogCapture_error() {

        enterCustomMessage()

        selectSeverityButton(.error)

        runLogTest()
    }

    func testLogCapture_fatal() {

        enterCustomMessage()

        selectSeverityButton(.fatal)

        runLogTest()
    }

    /// No Stack Trace

    func testLogCapture_warn_noStack() {

        enterCustomMessage()

        selectSeverityButton(.warn)
        selectStackTraceBehavior(.notIncluded)
        runLogTest()
    }

    func testLogCapture_error_noStack() {

        enterCustomMessage()

        selectSeverityButton(.error)
        selectStackTraceBehavior(.notIncluded)
        runLogTest()
    }

    /// Custom Stack Trace

    func testLogCapture_debug_customStack() {

        enterCustomMessage()

        selectSeverityButton(.debug)

        do {
            let stackTrace = try EmbraceStackTrace(frames: [
                "0 EmbraceIOTestApp 0x0000000005678def [SomeClass method] + 48",
                "1 Random Library 0x0000000001234abc [Random init]"
            ])

            selectStackTraceBehavior(.custom(stackTrace))
            runLogTest()
        } catch {
            XCTFail("testLogCapture_debug_customStack: Failed to create custom EmbraceStackTrace for test")
        }

    }

    /// Adding a property

    func testLogCapture_withProperty() {

        enterCustomMessage()
        selectSeverityButton(.warn)

        let logMessageAttributeKeyTextField = app.textFields["LogTestsAttributes_Key"]
        logMessageAttributeKeyTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageAttributeKeyTextField)

        logMessageAttributeKeyTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (logMessageAttributeKeyTextField.value as? String ?? "").count))

        logMessageAttributeKeyTextField.typeText("SomeCustomKey")
        logMessageAttributeKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let logMessageAttributeValueTextField = app.textFields["LogTestsAttributes_Value"]
        logMessageAttributeValueTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageAttributeValueTextField)

        logMessageAttributeValueTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (logMessageAttributeValueTextField.value as? String ?? "").count))

        logMessageAttributeValueTextField.typeText("Some Custom Value")
        logMessageAttributeValueTextField.typeText(XCUIKeyboardKey.return.rawValue)

        app.buttons["LogTestsAttributes_Insert_Button"].tap()

        runLogTest()
    }
}
