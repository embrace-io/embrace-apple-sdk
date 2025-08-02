//
//  SwiftUITestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum SwiftUITestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case swiftUIViewManual
    case swiftUIViewMacro
    case swiftUIViewEmbraceTraceView
    var title: String {
        switch self {
        case .swiftUIViewManual:
            "SwiftUI View Manual Capture"
        case .swiftUIViewMacro:
            "SwiftUI View Macro Capture"
        case .swiftUIViewEmbraceTraceView:
            "SwiftUI EmbraceTraceView Capture"
        }
    }

    var identifier: String {
        switch self {
        case .swiftUIViewManual:
            "swiftUIViewManualCaptureTestButton"
        case .swiftUIViewMacro:
            "swiftUIViewMacroCaptureTestButton"
        case .swiftUIViewEmbraceTraceView:
            "swiftUIEmbraceTraceViewCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .swiftUIViewManual:
            SwiftUIManualCaptureTestUIComponent(dataModel: self)
        case .swiftUIViewMacro:
            SwiftUIMacroCaptureTestUIComponent(dataModel: self)
        case .swiftUIViewEmbraceTraceView:
            SwiftUIEmbraceTraceViewCaptureTestUIComponent(dataModel: self)
        }
    }
}
