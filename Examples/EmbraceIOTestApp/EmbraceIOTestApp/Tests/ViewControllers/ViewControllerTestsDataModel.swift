//
//  ViewControllerTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum ViewControllerTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case viewDidLoad
    case viewDidAppearMeasurement

    var title: String {
        switch self {
        case .viewDidLoad:
            "viewDidLoad Capture"
        case .viewDidAppearMeasurement:
            "viewDidAppear Measurement Capture"
        }
    }

    var identifier: String {
        switch self {
        case .viewDidLoad:
            "viewDidLoadCaptureTestButton"
        case .viewDidAppearMeasurement:
            "viewDidAppearMeasurementCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .viewDidLoad:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: ViewControllerViewDidLoadTest()))
        case .viewDidAppearMeasurement:
            TestSpanScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: ViewControllerViewDidAppearTest()))
        }
    }
}
