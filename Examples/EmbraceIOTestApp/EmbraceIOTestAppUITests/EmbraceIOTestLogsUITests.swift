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
        XCTAssertTrue(initButton.waitForExistence(timeout: 5))
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        XCTAssertTrue(sideMenuButton.waitForExistence(timeout: 5))
        sideMenuButton.tap()

        let testScreen = app.staticTexts["logging"]
        XCTAssertTrue(testScreen.waitForExistence(timeout: 5))
        testScreen.tap()

        continueAfterFailure = true
    }

    override func tearDownWithError() throws {

    }

    private func enterCustomMessage() {
        let logMessageTextField = app.textFields["LogTests_LogMessage"]
        XCTAssertTrue(logMessageTextField.waitForExistence(timeout: 5))
        logMessageTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageTextField)

        logMessageTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue, count: (logMessageTextField.value as? String ?? "").count))

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
        case .critical:
            identifier = "LogSeverity_Critical"
        }

        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
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

        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func setAttachmentEnabled(_ enabled: Bool) {
        let toggle = app.switches["attachmentToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if (toggle.value as? String == "1") != enabled {
            toggle.tap()
        }
    }

    private enum AttachmentSize: Int {
        case safe
        case maxAllowed
        case overMaxAllowed
    }

    private func setAttachmentSize(_ size: AttachmentSize) {
        let slider = app.sliders["attachmentSizeSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))

        switch size {
        case .safe:
            slider.adjust(toNormalizedSliderPosition: 0.25)
        case .maxAllowed:
            slider.adjust(toNormalizedSliderPosition: 0.82)
        case .overMaxAllowed:
            slider.adjust(toNormalizedSliderPosition: 1.0)
        }
    }

    private func runLogTest() {
        let button = app.buttons["logMessageCaptureTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        evaluateTestResults(app)
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

    func testLogCapture_critical() {

        enterCustomMessage()

        selectSeverityButton(.critical)

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
    ///

    /// Force try is unsafe but this hardcoded scenario *should* always work.
    private var customStackTrace: EmbraceStackTrace {
        try! EmbraceStackTrace(frames: [
            "0 EmbraceIOTestApp 0x0000000005678def [SomeClass method] + 48",
            "1 Random Library 0x0000000001234abc [Random init]"
        ])
    }

    func testLogCapture_trace_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.trace)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func testLogCapture_debug_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.debug)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func testLogCapture_info_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.info)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func testLogCapture_warn_customStack_expected() {
        enterCustomMessage()

        selectSeverityButton(.warn)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func testLogCapture_error_customStack_expected() {
        enterCustomMessage()

        selectSeverityButton(.error)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func testLogCapture_fatal_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.fatal)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func testLogCapture_critical_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.critical)

        selectStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    /// Adding a property

    func testLogCapture_withProperty() {

        enterCustomMessage()
        selectSeverityButton(.warn)

        let logMessageAttributeKeyTextField = app.textFields["LogTestsAttributes_Key"]
        XCTAssertTrue(logMessageAttributeKeyTextField.waitForExistence(timeout: 5))
        logMessageAttributeKeyTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageAttributeKeyTextField)

        logMessageAttributeKeyTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: (logMessageAttributeKeyTextField.value as? String ?? "").count))

        logMessageAttributeKeyTextField.typeText("SomeCustomKey")
        logMessageAttributeKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let logMessageAttributeValueTextField = app.textFields["LogTestsAttributes_Value"]
        XCTAssertTrue(logMessageAttributeValueTextField.waitForExistence(timeout: 5))
        logMessageAttributeValueTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageAttributeValueTextField)

        logMessageAttributeValueTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: (logMessageAttributeValueTextField.value as? String ?? "").count))

        logMessageAttributeValueTextField.typeText("Some Custom Value")
        logMessageAttributeValueTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let button = app.buttons["LogTestsAttributes_Insert_Button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        runLogTest()
    }

    /// File Attachment

    func testLogCapture_withNormalFileSize() {
        enterCustomMessage()
        setAttachmentEnabled(true)
        setAttachmentSize(.safe)

        runLogTest()
    }

    func testLogCapture_withMaxFileSize() {
        enterCustomMessage()
        setAttachmentEnabled(true)
        setAttachmentSize(.maxAllowed)

        runLogTest()
    }

    func testLogCapture_withOversizeFileSize() {
        enterCustomMessage()
        setAttachmentEnabled(true)
        setAttachmentSize(.overMaxAllowed)

        runLogTest()
    }
}
