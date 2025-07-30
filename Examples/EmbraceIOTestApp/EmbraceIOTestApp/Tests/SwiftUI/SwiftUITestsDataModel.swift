//
//  SwiftUITestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum SwiftUITestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case swiftUIViewManual
    case swiftUIViewMacro
    var title: String {
        switch self {
        case .swiftUIViewManual:
            "SwiftUI View Manual Capture"
        case .swiftUIViewMacro:
            "SwiftUI View Macro Capture"
        }
    }

    var identifier: String {
        switch self {
        case .swiftUIViewManual:
            "swiftUIViewManualCaptureTestButton"
        case .swiftUIViewMacro:
            "swiftUIViewMacroCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .swiftUIViewManual:
            SwiftUICaptureTestView(dataModel: self, captureType: .manual)
        case .swiftUIViewMacro:
            SwiftUICaptureTestView(dataModel: self, captureType: .macro)
        }
    }
}
