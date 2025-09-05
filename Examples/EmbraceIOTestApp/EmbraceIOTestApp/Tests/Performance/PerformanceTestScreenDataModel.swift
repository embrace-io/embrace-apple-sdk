//
//  PerformanceTestScreenDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum PerformanceTestScreenDataModel: Int, TestScreenDataModel, CaseIterable {
    case logsPerformance = 0
    case spansPerformance

    var title: String {
        switch self {
        case .logsPerformance:
            "Log Performance Impact"
        case .spansPerformance:
            "Span Performance Impact"
        }
    }

    var identifier: String {
        switch self {
        case .logsPerformance:
            "logMessageCaptureTestButton"
        case .spansPerformance:
            "spanMessageCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .logsPerformance:
            PerformanceTestLogsUIComponent(dataModel: self)
        case .spansPerformance:
            PerformanceTestSpansUIComponent(dataModel: self)
        }
    }
}
