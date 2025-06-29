//
//  TestMenuOptionDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum TestMenuOptionDataModel: Int, CaseIterable {
    case embraceInit = 1000
    case startup
    case viewController
    case networking
    case logging
    case crashes
    case session
    case uploadedPayloads

    var title: String {
        switch self {
        case .embraceInit:
            "EmbraceIO Initialization"
        case .startup:
            "Startup Tests"
        case .viewController:
            "ViewController Tests"
        case .networking:
            "Networking Tests"
        case .logging:
            "Logging Tests"
        case .crashes:
            "Crashes Tests"
        case .session:
            "Session Payload Tests"
        case .uploadedPayloads:
            "Uploaded Payload Tests"
        }
    }

    var identifier: String {
        switch self {
        case .embraceInit:
            "embraceInit"
        case .startup:
            "metadata"
        case .viewController:
            "viewController"
        case .networking:
            "networking"
        case .logging:
            "logging"
        case .crashes:
            "crashes"
        case .session:
            "session"
        case .uploadedPayloads:
            "uploadedPayloads"
        }
    }

    @ViewBuilder var screen: some View {
        switch self {
        case .embraceInit:
            EmbraceInitScreen()
        case .startup:
            TestScreen<StartupTestsDataModel>()
        case .viewController:
            TestScreen<ViewControllerTestsDataModel>()
        case .networking:
            TestScreen<NetworkingTestsDataModel>()
        case .logging:
            TestScreen<LoggingTestScreenDataModel>()
        case .crashes:
            TestScreen<CrashesTestsDataModel>()
        case .session:
            TestScreen<SessionTestsDataModel>()
        case .uploadedPayloads:
            TestScreen<UploadedPayloadsTestsDataModel>()
        }
    }

    var tag: Int {
        self.rawValue
    }
}
