//
//  MetadataTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum MetadataTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case setup = 0
    case start
    case resourceMetadata

    var title: String {
        switch self {
        case .setup:
            "Setup Payload"
        case .start:
            "Start Payload"
        case .resourceMetadata:
            "Payload Resource Attributes"
        }
    }

    var identifier: String {
        switch self {
        case .setup:
            "setupPayloadTestButton"
        case .start:
            "startPayloadTestButton"
        case .resourceMetadata:
            "payloadResourceAttributesTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .setup:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: MetadataSetupPayloadTest()))
        case .start:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: MetadataStartupPayloadTest()))
        case .resourceMetadata:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: MetadataResourceTest()))
        }
    }
}
