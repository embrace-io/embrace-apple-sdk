//
//  TestMenuOptionDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum TestMenuOptionDataModel: Int, CaseIterable {
    case embraceInit = 1001
    case metadata = 1002
    case viewController = 1003
    case networking = 1004
    case logging = 1005

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
        }
    }

    @ViewBuilder var screen: some View {
        switch self {
        case .embraceInit:
            EmbraceInitScreen()
        case .metadata:
            MetadataTestScreen()
        case .viewController:
            TestScreen<ViewControllerTestsDataModel>()
        case .networking:
            TestScreen<NetworkingTestsDataModel>()
        case .logging:
            LoggingTestScreen()
        }
    }

    var tag: Int {
        self.rawValue
    }
}
