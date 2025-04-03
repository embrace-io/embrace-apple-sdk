//
//  MetadataTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum MetadataTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case setup = 0
    case start

    var title: String {
        switch self {
        case .setup:
            "Setup Payload"
        case .start:
            "Start Payload"
        }
    }

    var identifier: String {
        switch self {
        case .setup:
            "setupPayloadTestButton"
        case .start:
            "startPayloadTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .setup:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: MetadataSetupTest()))
        case .start:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: MetadataStartTest()))
        }
    }
}
