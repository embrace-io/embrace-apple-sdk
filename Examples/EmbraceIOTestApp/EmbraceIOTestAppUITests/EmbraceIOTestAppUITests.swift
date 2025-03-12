//
//  EmbraceIOTestAppUITests.swift
//  EmbraceIOTestAppUITests
//
//

import XCTest

final class EmbraceIOTestAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {

    }

    func testInitMetadataStartupPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()
        let startupButton = app.buttons["startupTestButton"]
        XCTAssertTrue(startupButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        startupButton.tap()
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testInitMetadataSetupPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()
        let startupButton = app.buttons["setupTestButton"]
        XCTAssertTrue(startupButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        startupButton.tap()
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testCrashPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["crashes"].tap()
        let crashButton = app.buttons["nullReferenceCrashCaptureTestButton"]
        XCTAssertTrue(crashButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        crashButton.tap()

        sleep(3)

        app.launch()
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        sideMenuButton.tap()

        app.staticTexts["crashes"].tap()

        XCTAssertTrue(crashButton.wait(for: \.isEnabled, toEqual: true, timeout: 5.0))

        crashButton.tap()

        sleep(3)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testLogCapture_info() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["logging"].tap()

        let logMessageTextField = app.textFields["LogTests_LogMessage"]
        logMessageTextField.tap()

        _ = waitUntilElementHasFocus(element: logMessageTextField)

        logMessageTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (logMessageTextField.value as? String ?? "").count))

        logMessageTextField.typeText("Some Custom Message")
        logMessageTextField.typeText(XCUIKeyboardKey.return.rawValue)

        app.buttons["LogSeverity_Info"].tap()

        app.buttons["logMessageCaptureTestButton"].tap()

        sleep(1)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }
}

extension XCUIElement {
    var hasFocus: Bool { value(forKey: "hasKeyboardFocus") as? Bool ?? false }
}

extension XCTestCase {
    func waitUntilElementHasFocus(element: XCUIElement, timeout: TimeInterval = 600, file: StaticString = #file, line: UInt = #line) -> XCUIElement {
        let expectation = expectation(description: "waiting for element \(element) to have focus")

        let timer = Timer(timeInterval: 1, repeats: true) { timer in
            guard element.hasFocus else { return }

            expectation.fulfill()
            timer.invalidate()
        }

        RunLoop.current.add(timer, forMode: .common)

        wait(for: [expectation], timeout: timeout)

        return element
    }
}
