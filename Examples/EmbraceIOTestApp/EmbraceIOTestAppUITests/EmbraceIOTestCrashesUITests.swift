//
//  EmbraceIOTestCrashesUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest

final class EmbraceIOTestCrashesUITests: XCTestCase {

    /// Removed for now as automated crash testing doesn't currently work due to the debugger catching the crash and pausing execution before a crash can be recorded.
    /// Will need to figure out a different solution.
    func disabled_testCrashPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertNotNil(initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["crashes"].tap()
        let crashButton = app.buttons["nullReferenceCrashCaptureTestButton"]
        XCTAssertNotNil(crashButton.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 5.0))

        crashButton.tap()

        sleep(3)

        app.launch()
        initButton.tap()
        XCTAssertNotNil(initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        sideMenuButton.tap()

        app.staticTexts["crashes"].tap()

        XCTAssertNotNil(crashButton.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 5.0))

        crashButton.tap()

        sleep(3)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }
}
