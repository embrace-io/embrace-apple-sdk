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
}
