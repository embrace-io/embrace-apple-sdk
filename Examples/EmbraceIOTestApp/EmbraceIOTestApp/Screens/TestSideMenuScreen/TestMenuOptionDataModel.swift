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
    case swiftui
    case networking
    case logging
    case crashes
    case session
    case uploadedPayloads
    case performance

    var title: String {
        switch self {
        case .embraceInit:
            "EmbraceIO Initialization"
        case .startup:
            "Startup Tests"
        case .viewController:
            "ViewController Tests"
        case .swiftui:
            "SwiftUI Tests"
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
        case .performance:
            "Performance Tests"
        }
    }

    var identifier: String {
        switch self {
        case .embraceInit:
            "embraceInit"
        case .startup:
            "startup"
        case .viewController:
            "viewController"
        case .swiftui:
            "swiftui"
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
        case .performance:
            "performance"
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
        case .swiftui:
            TestScreen<SwiftUITestsDataModel>()
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
        case .performance:
            TestScreen<PerformanceTestScreenDataModel>()
        }
    }

    var tag: Int {
        self.rawValue
    }
}
