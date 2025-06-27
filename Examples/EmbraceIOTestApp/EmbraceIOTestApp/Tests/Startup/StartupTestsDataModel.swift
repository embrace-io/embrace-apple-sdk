//
//  StartupTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum StartupTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case preMain = 0
    case sdkSetup
    case sdkStart
    case startProcess
    case startState
    case processLaunch
    case appStartup
    case firstFrameCapture
    case resourceMetadata

    var title: String {
        switch self {
        case .preMain:
            "Pre-Main Payload"
        case .sdkSetup:
            "SDK Setup Span"
        case .sdkStart:
            "SDK Start Span"
        case .startProcess:
            "Startup Process Span"
        case .startState:
            "Startup State Span"
        case .processLaunch:
            "Process Launch Span"
        case .appStartup:
            "App Startup Init Span"
        case .firstFrameCapture:
            "First Frame Capture Span"
        case .resourceMetadata:
            "Payload Resource Attributes"
        }
    }

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

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .preMain:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupPreMainPayloadTest()))
        case .sdkSetup:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupSDKSetupSpanTest()))
        case .sdkStart:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupSDKStartSpanTest()))
        case .startProcess:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupStartupProcessSpanTest()))
        case .startState:
            StartupStateTestUIComponent(dataModel: self)
        case .processLaunch:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupProcessLaunchSpanTest()))
        case .appStartup:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupAppStartupInitSpanTest()))
        case .firstFrameCapture:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: StartupFirstFrameSpanTest()))
        case .resourceMetadata:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: MetadataResourceTest()))
        }
    }
}
