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
        XCTAssertNotNil(button.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 10.0))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }

    func testAllWarmStartupCases() {
        caseTestInitStartup_PreMain_Span()
        app.swipeDown()
        caseTestInitStartup_SDKSetup_Span()
        app.swipeDown()
        caseTestInitStartup_SDKSetart_Span()
        app.swipeDown()
        caseTestInitStartup_StartProcess_Span()
        app.swipeDown()
        caseTestInitStartup_StartState_Warm_Span()
        app.swipeDown()
        caseTestInitStartup_ProcessLaunch_Span()
        app.swipeDown()
        caseTestInitStartup_AppStartup_Span()
        app.swipeDown()
        caseTestInitStartup_FirstFrameCapture_Span()
        app.swipeDown()
        caseTestInitStartup_MetadataItems()
    }

    func caseTestInitStartup_PreMain_Span() {
        selectMetadataTest(.startProcess)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_SDKSetup_Span() {
        selectMetadataTest(.sdkSetup)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_SDKSetart_Span() {
        selectMetadataTest(.sdkStart)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_StartProcess_Span() {
        selectMetadataTest(.startProcess)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_StartState_Warm_Span() {
        selectMetadataTest(.startState)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_ProcessLaunch_Span() {
        selectMetadataTest(.processLaunch)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_AppStartup_Span() {
        selectMetadataTest(.appStartup)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_FirstFrameCapture_Span() {
        selectMetadataTest(.firstFrameCapture)
        evaluateTestResults(app)
    }

    func caseTestInitStartup_MetadataItems() {
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
        XCTAssertTrue(app.scrollUntilHittableElementVisible(expectedColdStart))
        expectedColdStart.tap()

        let button = app.buttons["startupStateSpanTestButton"]
        XCTAssertNotNil(button.wait(attribute: \.isEnabled, is: .equalTo, value: true, timeout: 10.0))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))

        button.tap()
        evaluateTestResults(app)
        app.swipeDown()
    }
}
