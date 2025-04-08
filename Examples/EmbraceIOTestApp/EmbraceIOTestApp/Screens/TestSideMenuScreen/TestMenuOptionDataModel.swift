//
//  TestMenuOptionDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum TestMenuOptionDataModel: Int, CaseIterable {
    case embraceInit = 1000
    case metadata
    case viewController
    case networking
    case logging
    case crashes
    case session

    var title: String {
        switch self {
        case .embraceInit:
            "EmbraceIO Initialization"
        case .metadata:
            "Metadata Tests"
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
        }
    }

    var identifier: String {
        switch self {
        case .embraceInit:
            "embraceInit"
        case .metadata:
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
        }
    }

    @ViewBuilder var screen: some View {
        switch self {
        case .embraceInit:
            EmbraceInitScreen()
        case .metadata:
            TestScreen<MetadataTestsDataModel>()
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
        }
    }

    var tag: Int {
        self.rawValue
    }
}
