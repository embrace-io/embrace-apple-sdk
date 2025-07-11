//
//  SwiftUITestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum SwiftUITestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case swiftUIView
    var title: String {
        switch self {
        case .swiftUIView:
            "SwiftUI View Capture"
        }
    }

    var identifier: String {
        switch self {
        case .swiftUIView:
            "swiftUIViewCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .swiftUIView:
            SwiftUICaptureTestView(dataModel: self)
        }
    }
}
