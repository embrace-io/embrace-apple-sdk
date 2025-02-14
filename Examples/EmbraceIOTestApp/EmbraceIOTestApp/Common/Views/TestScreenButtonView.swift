//
//  TestScreenButtonView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestScreenButtonView: View {
    @State var viewModel: any UIComponentViewModelType
    @State var presentReport: Bool = false
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
            .accessibilityIdentifier(viewModel.dataModel.identifier)
        }
        .frame(height: 60)
        .background(viewModel.testResult.resultColor)
        .onChange(of: viewModel.state, { oldValue, newValue in
            if case .testComplete(_) = newValue {
                presentReport = true
            }
        })
        .sheet(isPresented: $presentReport) {
            TestReportCard(report: viewModel.testReport)
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    VStack {
        TestScreenButtonView(viewModel: SpanTestUIComponentViewModel(dataModel: ViewControllerTestsDataModel.viewDidLoad))
    }
}
