//
//  SessionTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum SessionTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case finishedSessionPayload

    var title: String {
        switch self {
        case .finishedSessionPayload:
            "Finished Session Payload"
        }
    }

    var identifier: String {
        switch self {
        case .finishedSessionPayload:
            "finishedSessionPayloadTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .finishedSessionPayload:
            SessionTestFinishedSessionUIComponent(dataModel: self)
        }
    }
}
