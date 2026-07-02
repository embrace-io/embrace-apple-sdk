//
//  SessionTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum SessionTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case finishedSessionPayload
    case userSession

    var title: String {
        switch self {
        case .finishedSessionPayload:
            "Finished Session Payload"
        case .userSession:
            "End User Session"
        }
    }

    var identifier: String {
        switch self {
        case .finishedSessionPayload:
            "finishedSessionPayloadTestButton"
        case .userSession:
            "userSessionTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .finishedSessionPayload:
            SessionTestFinishedSessionUIComponent(dataModel: self)
        case .userSession:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: UserSessionTest()))
        }
    }
}
