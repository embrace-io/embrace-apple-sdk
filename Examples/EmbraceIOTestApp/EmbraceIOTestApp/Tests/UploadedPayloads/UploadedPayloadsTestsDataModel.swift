//
//  UploadedPayloadsTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum UploadedPayloadsTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case sessionPayload

    var title: String {
        switch self {
        case .sessionPayload:
            "Session Payload"
        }
    }

    var identifier: String {
        switch self {
        case .sessionPayload:
            "sessionPayloadTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .sessionPayload:
            UploadedSessionPayloadUIComponent(dataModel: self)
        }
    }
}
