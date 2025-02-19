//
//  LoggingTestScreenDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum LoggingTestScreenDataModel: Int, TestScreenDataModel, CaseIterable {
    case errorLogMessage = 0

    var title: String {
        switch self {
        case .errorLogMessage:
            "Error Log Message Capture"
        }
    }

    var identifier: String {
        switch self {
        case .errorLogMessage:
            "errorLogMessageCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .errorLogMessage:
            LoggingTestLogMessageUIComponent(dataModel: self)
        }
    }
}
