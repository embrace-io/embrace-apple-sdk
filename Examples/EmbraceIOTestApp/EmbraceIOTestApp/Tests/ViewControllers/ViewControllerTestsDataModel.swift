//
//  ViewControllerTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum ViewControllerTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case viewDidLoad = 0

    var title: String {
        switch self {
        case .viewDidLoad:
            "viewDidLoad Capture"
        }
    }

    var identifier: String {
        switch self {
        case .viewDidLoad:
            "viewDidLoadCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .viewDidLoad:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: ViewControllerViewDidLoadTest()))
        }
    }
}
