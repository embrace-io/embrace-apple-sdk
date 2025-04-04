//
//  CrashesTestsDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum CrashesTestsDataModel: Int, TestScreenDataModel, CaseIterable {
    case nullReference = 0

    var title: String {
        switch self {
        case .nullReference:
            "Null Pointer Crash Capture"
        }
    }

    var identifier: String {
        switch self {
        case .nullReference:
            "nullReferenceCrashCaptureTestButton"
        }
    }

    @ViewBuilder var uiComponent: some View {
        switch self {
        case .nullReference:
            TestLogScreenButtonView(viewModel: .init(dataModel: self, payloadTestObject: CrashesTests()))
        }
    }
}
