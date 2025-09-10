//
//  EmbraceIOTestSwiftUI.swift
//  EmbraceIOTestApp
//
//

import XCTest

@testable import EmbraceCommonInternal

final class EmbraceIOTestSwiftUI: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchAndOpenTestTab("swiftui")
    }

    override func tearDownWithError() throws {

    }

    func testAllSwiftUICases() {
        caseManualCapture()
        app.swipeDown()
        caseManualCapture_ContentComplete()
        app.swipeDown()
        caseManualCapture_AddProperty()
        app.swipeDown()
        caseMacroCapture()
        app.swipeDown()
        caseEmbraceTraceViewCapture()
        app.swipeDown()
        caseEmbraceTraceViewCapture_ContentComplete()
        app.swipeDown()
        caseEmbraceTraceViewCapture_AddProperty()
    }

    /// Manual Capture
    func caseManualCapture() {
        toggle("manualCaptureContentComplete", value: false)
        runTest("swiftUIViewManualCaptureTestButton")

        evaluateTestResults(app)
    }

    func caseManualCapture_ContentComplete() {
        toggle("manualCaptureContentComplete", value: true)
        runTest("swiftUIViewManualCaptureTestButton")

        evaluateTestResults(app)
    }

    func caseManualCapture_AddProperty() {
        addManualCaptureProperty(key: "someKey", value: "someValue")
        runTest("swiftUIViewManualCaptureTestButton")

        evaluateTestResults(app)
    }

    /// Macro Capture

    func caseMacroCapture() {
        runTest("swiftUIViewMacroCaptureTestButton")

        evaluateTestResults(app)
    }

    /// Embrace Trace View Capture
    func caseEmbraceTraceViewCapture() {
        toggle("embraceTraceViewCaptureContentComplete", value: false)
        runTest("swiftUIEmbraceTraceViewCaptureTestButton")

        evaluateTestResults(app)
    }

    func caseEmbraceTraceViewCapture_ContentComplete() {
        toggle("embraceTraceViewCaptureContentComplete", value: true)
        runTest("swiftUIEmbraceTraceViewCaptureTestButton")

        evaluateTestResults(app)
    }

    func caseEmbraceTraceViewCapture_AddProperty() {
        addEmbraceTraceViewCaptureProperty(key: "someKey", value: "someValue")
        runTest("swiftUIEmbraceTraceViewCaptureTestButton")

        evaluateTestResults(app)
    }

    /// Helpers

    private func toggle(_ name: String, value: Bool) {
        let toggle = app.switches[name]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(toggle))
        if (toggle.value as? String == "1") != value {
            toggle.tap()
        }
    }

    private func runTest(_ name: String) {
        let button = app.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }

    private func addManualCaptureProperty(key: String, value: String) {
        enterProperty(key: key, keyIdentifier: "manualCapturePropertyKey", value: value, valueIdentifier: "manualCapturePropertyValue", addButtonIdentifier: "manualCaptureAddProperty")
    }

    private func addEmbraceTraceViewCaptureProperty(key: String, value: String) {
        enterProperty(
            key: key, keyIdentifier: "embraceTraceViewCapturePropertyKey", value: value, valueIdentifier: "embraceTraceViewCapturePropertyValue",
            addButtonIdentifier: "embraceTraceViewCaptureAddProperty")
    }

    private func enterProperty(key: String, keyIdentifier: String, value: String, valueIdentifier: String, addButtonIdentifier: String) {
        let logMessageAttributeKeyTextField = app.textFields[keyIdentifier]
        XCTAssertTrue(logMessageAttributeKeyTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(logMessageAttributeKeyTextField))
        logMessageAttributeKeyTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageAttributeKeyTextField)

        logMessageAttributeKeyTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: (logMessageAttributeKeyTextField.value as? String ?? "").count))

        logMessageAttributeKeyTextField.typeText(key)
        logMessageAttributeKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let logMessageAttributeValueTextField = app.textFields[valueIdentifier]
        XCTAssertTrue(logMessageAttributeValueTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(logMessageAttributeValueTextField))
        logMessageAttributeValueTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageAttributeValueTextField)

        logMessageAttributeValueTextField.typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: (logMessageAttributeValueTextField.value as? String ?? "").count))

        logMessageAttributeValueTextField.typeText(value)
        logMessageAttributeValueTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let button = app.buttons[addButtonIdentifier]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }
}
