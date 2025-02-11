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
            EmptyView()
            //NetworkingTestUIComponent(dataModel: self)
        }
    }

    var payloadTestObject: PayloadTest {
        switch self {
        case .networkCall:
            NetworkingTest(testURL: "", statusCode: 200)
        }
    }
}
