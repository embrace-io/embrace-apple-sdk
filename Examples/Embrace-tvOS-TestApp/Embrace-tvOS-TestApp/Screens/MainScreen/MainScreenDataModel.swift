//
//  MainScreenDataModel.swift
//  tvosTestApp
//
//

import SwiftUI

enum MainScreenDataModel: Int, CaseIterable {
    case channels
    case session
    case network
    case logs
    case metadata
    case crashes

    var title: String {
        switch self {
        case .channels: "Channels Experience"
        case .session: "Session Tests"
        case .logs: "Custom Log Tests"
        case .network: "Network Tests"
        case .metadata: "Metadata Tests"
        case .crashes: "Crash Tests"
        }
    }

    var identifier: String {
        switch self {
        case .channels: "channelsExperience"
        case .session: "sessionTests"
        case .logs: "customLogTests"
        case .network: "networkTests"
        case .metadata: "metadataTests"
        case .crashes: "crashTests"
        }
    }

    @ViewBuilder var screen: some View {
        switch self {
        case .channels:
            ChannelsScreen()
        case .session:
            SessionTestsScreen()
        case .logs:
            CustomLogsTestsScreen()
        case .network:
            NetworkTestsScreen()
        case .metadata:
            MetadataTestsScreen()
        case .crashes:
            CrashTestsScreen()
        }
    }
}
