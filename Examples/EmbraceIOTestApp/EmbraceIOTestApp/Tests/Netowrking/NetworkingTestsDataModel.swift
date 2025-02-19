//
//  NetworkingTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum NetworkingTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case networkCall = 0

    var title: String {
        switch self {
        case .networkCall:
            "Network Call"
        }
    }

    var identifier: String {
        switch self {
        case .networkCall:
            "networkCallTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .networkCall:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: NetworkingTest()))
        }
    }
}
