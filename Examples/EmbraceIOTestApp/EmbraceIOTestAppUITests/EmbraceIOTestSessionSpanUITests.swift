//
//  EmbraceIOTestSessionSpanUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest

@testable import EmbraceCommonInternal

final class EmbraceIOTestSessionSpanUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchAndOpenTestTab("session")
    }

    private func backgroundAndReopenApp() {
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        let backgrounded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state == %d", XCUIApplication.State.runningBackground.rawValue),
            object: app)
        let result = XCTWaiter.wait(for: [backgrounded], timeout: 10)
        XCTAssertEqual(result, .completed, "app didn't background in 10s")
        app.activate()
    }

    private func runSessionSpanTest() {
        let button = app.buttons["finishedSessionPayloadTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }

    func testSendFinishedSessionSpan() {
        runSessionSpanTest()
        // Brief pause to let the SDK record the span before the session ends on background.
        // TODO: replace with a UI signal once the app exposes span-written state.
        sleep(2)
        backgroundAndReopenApp()
        evaluateTestResults(app)
    }
}
