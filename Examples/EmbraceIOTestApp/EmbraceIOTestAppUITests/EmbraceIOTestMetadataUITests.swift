//
//  EmbraceIOTestMetadataUITests.swift
//  EmbraceIOTestMetadataUITests
//
//

import XCTest

final class EmbraceIOTestMetadataUITests: XCTestCase {
    /// UI Tests do not run the same way Unit Test do. Doing this is MUCH easier than adding the whole source file list, plus their dependencies, to the UI Test target.
    /// An app that exports its source as a library and then includes it can work around this issue for for now, a simple copy/paste will do.
    enum Test: Int, CaseIterable {
        case setup = 0
        case start
        case resourceMetadata

        var identifier: String {
            switch self {
            case .setup:
                "setupPayloadTestButton"
            case .start:
                "startPayloadTestButton"
            case .resourceMetadata:
                "payloadResourceAttributesTestButton"
            }
        }
    }

    var app = XCUIApplication()
    override func setUpWithError() throws {
        app.launch()
        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertNotNil(initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()
        //sleep(4)
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {

    }

    private func selectMetadataTest(_ test: Test) {
        let button = app.buttons[test.identifier]
        XCTAssertNotNil(button.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 5.0))

        button.tap()
    }

    private func evaluateResults() {
        sleep(2)
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testInitMetadataStartupPayload() {
        selectMetadataTest(.start)
        evaluateResults()
    }

    func testInitMetadataSetupPayload() {
        selectMetadataTest(.setup)
        evaluateResults()
    }

    func testResourceMetadataItems() {
        selectMetadataTest(.resourceMetadata)
        evaluateResults()
    }
}
