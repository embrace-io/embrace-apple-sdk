//
//  EmbraceIOTestLogsUITests.swift
//  EmbraceIOTestApp
//
//

import EmbraceSemantics
import XCTest

final class EmbraceIOTestLogsUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchAndOpenTestTab("logging")
    }

    override func tearDownWithError() throws {

    }

    private func enterCustomMessage() {
        let logMessageTextField = app.textFields["LogTests_LogMessage"]
        XCTAssertTrue(logMessageTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(logMessageTextField))
        logMessageTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        logMessageTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue, count: (logMessageTextField.value as? String ?? "").count))

        logMessageTextField.typeText("Some Custom Message")
        logMessageTextField.typeText(XCUIKeyboardKey.return.rawValue)
    }

    private func selectSeverityButton(_ severity: EmbraceLogSeverity) {
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
            XCTFail("Critial Logs are for internal use only. Do not test these with the UI app as these are out of scope.")
        }

        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }

    private func selectEmbraceStackTraceBehavior(_ behavior: EmbraceStackTraceBehavior) {
        var identifier = ""
        switch behavior {
        case .default:
            identifier = "stackTraceBehavior_Default"
        case .notIncluded:
            identifier = "stackTraceBehavior_notIncluded"
        case .custom:
            identifier = "stackTraceBehavior_custom"
        case .main:
            identifier = "stackTraceBehavior_main"
        }

        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }

    private func setAttachmentEnabled(_ enabled: Bool) {
        let toggle = app.switches["attachmentToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(toggle))
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
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(slider))
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
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
        evaluateTestResults(app)
    }

    func test_logCapture_trace() {

        enterCustomMessage()

        selectSeverityButton(.trace)

        runLogTest()
    }

    func test_logCapture_debug() {

        enterCustomMessage()

        selectSeverityButton(.debug)

        runLogTest()
    }

    func test_logCapture_info() {

        enterCustomMessage()

        selectSeverityButton(.info)

        runLogTest()
    }

    func test_logCapture_warn() {

        enterCustomMessage()

        selectSeverityButton(.warn)

        runLogTest()
    }

    func test_logCapture_error() {

        enterCustomMessage()

        selectSeverityButton(.error)

        runLogTest()
    }

    func test_logCapture_fatal() {

        enterCustomMessage()

        selectSeverityButton(.fatal)

        runLogTest()
    }

    /// No Stack Trace

    func test_logCapture_warn_noStack() {

        enterCustomMessage()

        selectSeverityButton(.warn)
        selectEmbraceStackTraceBehavior(.notIncluded)
        runLogTest()
    }

    func test_logCapture_error_noStack() {

        enterCustomMessage()

        selectSeverityButton(.error)
        selectEmbraceStackTraceBehavior(.notIncluded)
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

    func test_logCapture_trace_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.trace)

        selectEmbraceStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func test_logCapture_debug_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.debug)

        selectEmbraceStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func test_logCapture_info_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.info)

        selectEmbraceStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func test_logCapture_warn_customStack_expected() {
        enterCustomMessage()

        selectSeverityButton(.warn)

        selectEmbraceStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func test_logCapture_error_customStack_expected() {
        enterCustomMessage()

        selectSeverityButton(.error)

        selectEmbraceStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    func test_logCapture_fatal_customStack_notExpected() {
        enterCustomMessage()

        selectSeverityButton(.fatal)

        selectEmbraceStackTraceBehavior(.custom(customStackTrace))
        runLogTest()
    }

    /// Adding a property

    func test_logCapture_withProperty() {

        enterCustomMessage()
        selectSeverityButton(.warn)

        let logMessageAttributeKeyTextField = app.textFields["LogTestsAttributes_Key"]
        XCTAssertTrue(logMessageAttributeKeyTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(logMessageAttributeKeyTextField))
        logMessageAttributeKeyTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        logMessageAttributeKeyTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: (logMessageAttributeKeyTextField.value as? String ?? "").count))

        logMessageAttributeKeyTextField.typeText("SomeCustomKey")
        logMessageAttributeKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let logMessageAttributeValueTextField = app.textFields["LogTestsAttributes_Value"]
        XCTAssertTrue(logMessageAttributeValueTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(logMessageAttributeValueTextField))
        logMessageAttributeValueTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        logMessageAttributeValueTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: (logMessageAttributeValueTextField.value as? String ?? "").count))

        logMessageAttributeValueTextField.typeText("Some Custom Value")
        logMessageAttributeValueTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let button = app.buttons["LogTestsAttributes_Insert_Button"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()

        runLogTest()
    }

    /// File Attachment

    func test_logCapture_withNormalFileSize() {
        enterCustomMessage()
        setAttachmentEnabled(true)
        setAttachmentSize(.safe)

        runLogTest()
    }

    func test_logCapture_withMaxFileSize() {
        enterCustomMessage()
        setAttachmentEnabled(true)
        setAttachmentSize(.maxAllowed)

        runLogTest()
    }

    func test_logCapture_withOversizeFileSize() {
        enterCustomMessage()
        setAttachmentEnabled(true)
        setAttachmentSize(.overMaxAllowed)

        runLogTest()
    }
}
