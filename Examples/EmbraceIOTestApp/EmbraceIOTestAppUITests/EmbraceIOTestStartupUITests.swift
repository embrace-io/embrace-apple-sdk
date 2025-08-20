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
        continueAfterFailure = true
        app.launchAndOpenTestTab("startup")
    }

    private func selectMetadataTest(_ test: Test) {
        let button = app.buttons[test.identifier]
        XCTAssertNotNil(button.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 5.0))

        button.tap()
    }

    func testInitStartup_PreMain_Span() {
        selectMetadataTest(.startProcess)
        evaluateTestResults(app)
    }

    func testInitStartup_SDKSetup_Span() {
        selectMetadataTest(.sdkSetup)
        evaluateTestResults(app)
    }

    func testInitStartup_SDKSetart_Span() {
        selectMetadataTest(.sdkStart)
        evaluateTestResults(app)
    }

    func testInitStartup_StartProcess_Span() {
        selectMetadataTest(.startProcess)
        evaluateTestResults(app)
    }

    func testInitStartup_StartState_Warm_Span() {
        selectMetadataTest(.startState)
        evaluateTestResults(app)
    }

    func testInitStartup_ProcessLaunch_Span() {
        selectMetadataTest(.processLaunch)
        evaluateTestResults(app)
    }

    func testInitStartup_AppStartup_Span() {
        selectMetadataTest(.appStartup)
        evaluateTestResults(app)
    }

    func testInitStartup_FirstFrameCapture_Span() {
        selectMetadataTest(.firstFrameCapture)
        evaluateTestResults(app)
    }

    func testInitStartup_MetadataItems() {
        selectMetadataTest(.resourceMetadata)
        evaluateTestResults(app)
    }
}

final class EmbraceIOTestCOLDStartupUITests: XCTestCase {
    var app = XCUIApplication()
    override func setUpWithError() throws {
        app.launchAndOpenTestTab("startup", coldStart: true)
    }

    func testInitStartup_StartState_Cold_Span() {
        let expectedColdStart = app.switches["coldStartExpectedToggle"].switches.firstMatch
        XCTAssertTrue(expectedColdStart.waitForExistence(timeout: 10))
        expectedColdStart.tap()

        let button = app.buttons["startupStateSpanTestButton"]
        XCTAssertNotNil(button.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 5.0))

        button.tap()
        evaluateTestResults(app)
    }
}
