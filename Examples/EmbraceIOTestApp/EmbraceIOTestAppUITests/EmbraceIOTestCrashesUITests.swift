//
//  EmbraceIOTestCrashesUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest

final class EmbraceIOTestCrashesUITests: XCTestCase {

    /// Removed for now as automated crash testing doesn't currently work due to the debugger catching the crash and pausing execution before a crash can be recorded.
    /// Will need to figure out a different solution.
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchAndOpenTestTab("crashes")
    }

    func disabled_testCrashPayload() {
        sleep(3)
        let crashButton = app.buttons["nullReferenceCrashCaptureTestButton"]
        crashButton.tap()

        sleep(3)

        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }
}
