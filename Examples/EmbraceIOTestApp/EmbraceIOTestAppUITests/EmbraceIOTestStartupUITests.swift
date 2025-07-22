//
//  EmbraceIOTestStartupUITests.swift
//  EmbraceIOTestStartupUITests
//
//

import XCTest

final class EmbraceIOTestWARMStartupUITests: XCTestCase {
    /// UI Tests do not run the same way Unit Test do. Doing this is MUCH easier than adding the whole source file list, plus their dependencies, to the UI Test target.
    /// An app that exports its source as a library and then includes it can work around this issue for for now, a simple copy/paste will do.
    enum Test: Int, CaseIterable {
        case preMain = 0
        case sdkSetup
        case sdkStart
        case startProcess
        case startState
        case processLaunch
        case appStartup
        case firstFrameCapture
        case resourceMetadata

        var identifier: String {
            switch self {
            case .preMain:
                "setupPayloadTestButton"
            case .sdkSetup:
                "sdkSetupSpanTestButton"
            case .sdkStart:
                "sdkStartSpanTestButton"
            case .startProcess:
                "startProcessSpanTestButton"
            case .startState:
                "startupStateSpanTestButton"
            case .processLaunch:
                "processLaunchSpanTestButton"
            case .appStartup:
                "appStartupInitSpanTestButton"
            case .firstFrameCapture:
                "firstFrameCaptureSpanTestButton"
            case .resourceMetadata:
                "payloadResourceAttributesTestButton"
            }
        }
    }

    var app = XCUIApplication()
    override func setUpWithError() throws {
        app.launch()

        let warmButton = app.buttons["EmbraceInitForceState_Warm"]
        warmButton.tap()

        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()
        //sleep(4)
        continueAfterFailure = true
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

    func testInitStartup_PreMain_Span() {
        selectMetadataTest(.startProcess)
        evaluateResults()
    }

    func testInitStartup_SDKSetup_Span() {
        selectMetadataTest(.sdkSetup)
        evaluateResults()
    }

    func testInitStartup_SDKSetart_Span() {
        selectMetadataTest(.sdkStart)
        evaluateResults()
    }

    func testInitStartup_StartProcess_Span() {
        selectMetadataTest(.startProcess)
        evaluateResults()
    }

    func testInitStartup_StartState_Warm_Span() {
        selectMetadataTest(.startState)
        evaluateResults()
    }

    func testInitStartup_ProcessLaunch_Span() {
        selectMetadataTest(.processLaunch)
        evaluateResults()
    }

    func testInitStartup_AppStartup_Span() {
        selectMetadataTest(.appStartup)
        evaluateResults()
    }

    func testInitStartup_FirstFrameCapture_Span() {
        selectMetadataTest(.firstFrameCapture)
        evaluateResults()
    }

    func testInitStartup_MetadataItems() {
        selectMetadataTest(.resourceMetadata)
        evaluateResults()
    }
}

final class EmbraceIOTestCOLDStartupUITests: XCTestCase {
    var app = XCUIApplication()
    override func setUpWithError() throws {
        app.launch()

        let coldButton = app.buttons["EmbraceInitForceState_Cold"]
        coldButton.tap()

        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["metadata"].tap()

        continueAfterFailure = true
    }

    private func evaluateResults() {
        sleep(2)
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }

    func testInitStartup_StartState_Cold_Span() {
        let expectedColdStart = app.switches["coldStartExpectedToggle"].switches.firstMatch
        expectedColdStart.tap()

        let button = app.buttons["startupStateSpanTestButton"]
        XCTAssertNotNil(button.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 5.0))

        button.tap()
        evaluateResults()
    }
}
