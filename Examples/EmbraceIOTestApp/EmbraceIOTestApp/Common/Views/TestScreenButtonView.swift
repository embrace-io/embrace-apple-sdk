//
//  TestScreenButtonView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestScreenButtonView: View {
    var viewModel: any UIComponentViewModelType
    @State private var presentReport = false
    var body: some View {
        HStack {
            Button {
                viewModel.testButtonPressed()
            } label: {
                TestComponentViewLabel(text: viewModel.dataModel.title, result: .constant(viewModel.testResult))
                    .foregroundStyle(.embraceSilver.opacity(viewModel.readyToTest ? 1.0 : 0.5))
            }
            .disabled(!viewModel.readyToTest)
            .accessibilityIdentifier(viewModel.dataModel.identifier)
        }
        .frame(height: 60)
        .background(viewModel.testResult.resultColor)
        .sheet(isPresented: $presentReport) {
            TestReportCard(report: viewModel.testReport)
        }
        .onChange(of: viewModel.presentReport) { oldValue, newValue in
            self.presentReport = newValue
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    VStack {
        TestScreenButtonView(viewModel: SpanTestUIComponentViewModel(dataModel: ViewControllerTestsDataModel.viewDidLoad))
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
