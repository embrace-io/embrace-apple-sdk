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

    /// Manual Capture
    func test_manualCapture() {
        toggle("manualCaptureContentComplete", value: false)
        runTest("swiftUIViewManualCaptureTestButton")

        evaluateTestResults(app)
    }

    func test_manualCapture_ContentComplete() {
        toggle("manualCaptureContentComplete", value: true)
        runTest("swiftUIViewManualCaptureTestButton")

        evaluateTestResults(app)
    }

    func test_manualCapture_AddProperty() {
        addManualCaptureProperty(key: "someKey", value: "someValue")
        runTest("swiftUIViewManualCaptureTestButton")

        evaluateTestResults(app)
    }

    /// Macro Capture

    func test_macroCapture() {
        runTest("swiftUIViewMacroCaptureTestButton")

        evaluateTestResults(app)
    }

    /// Embrace Trace View Capture
    func test_embraceTraceViewCapture() {
        toggle("embraceTraceViewCaptureContentComplete", value: false)
        runTest("swiftUIEmbraceTraceViewCaptureTestButton")

        evaluateTestResults(app)
    }

    func test_embraceTraceViewCapture_ContentComplete() {
        toggle("embraceTraceViewCaptureContentComplete", value: true)
        runTest("swiftUIEmbraceTraceViewCaptureTestButton")

        evaluateTestResults(app)
    }

    func test_embraceTraceViewCapture_AddProperty() {
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

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

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

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

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
