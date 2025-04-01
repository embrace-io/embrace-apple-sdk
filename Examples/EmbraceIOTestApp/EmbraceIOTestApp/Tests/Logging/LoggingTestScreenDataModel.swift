//
//  LoggingTestScreenDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum LoggingTestScreenDataModel: Int, TestScreenDataModel, CaseIterable {
    case logMessage = 0

    var title: String {
        switch self {
        case .logMessage:
            "Log Message Capture"
        }
    }

    var identifier: String {
        switch self {
        case .logMessage:
            "logMessageCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .logMessage:
            LoggingTestLogMessageUIComponent(dataModel: self)
        }
    }
}
