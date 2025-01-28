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

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    func testInitMetadataPayload() {
        let app = XCUIApplication()

        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertTrue(initButton.wait(for: \.label, toEqual: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()
    }
}
