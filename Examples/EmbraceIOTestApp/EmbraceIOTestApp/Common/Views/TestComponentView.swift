//
//  TestComponentView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestComponentView<ViewModel: UIComponentViewModelType>: View {
    @StateObject var viewModel: ViewModel

    var body: some View {
        HStack {
            Button {
                viewModel.testButtonPressed()
            } label: {
                TestComponentViewLabel(text: viewModel.dataModel.title,
                                       state: viewModel.state)
                    .foregroundStyle(.embraceSilver.opacity(viewModel.readyToTest ? 1.0 : 0.5))
            }
            .disabled(!viewModel.readyToTest)
        }
        .frame(height: 60)
        .background(viewModel.testResult.resultColor)
    }
}

#Preview {
    VStack {
//        TestComponentView(testResult: .constant(.unknown),
//                          readyForTest: .constant(true),
//                          testName: "Test",
//                          testAction: {})
//        TestComponentView(testResult: .constant(.unknown),
//                          readyForTest: .constant(false),
//                          testName: "Test",
//                          testAction: {})
//        TestComponentView(testResult: .constant(.testing),
//                          readyForTest: .constant(false),
//                          testName: "Test",
//                          testAction: {})
//        TestComponentView(testResult: .constant(.success),
//                          readyForTest: .constant(true),
//                          testName: "Test",
//                          testAction: {})
//        TestComponentView(testResult: .constant(.success),
//                          readyForTest: .constant(false),
//                          testName: "Test",
//                          testAction: {})
//        TestComponentView(testResult: .constant(.fail),
//                          readyForTest: .constant(true),
//                          testName: "Test",
//                          testAction: {})
//        TestComponentView(testResult: .constant(.fail),
//                          readyForTest: .constant(false),
//                          testName: "Test",
//                          testAction: {})
    }
}
