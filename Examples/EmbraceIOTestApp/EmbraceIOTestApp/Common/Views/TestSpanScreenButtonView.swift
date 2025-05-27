//
//  TestSpanScreenButtonView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestSpanScreenButtonView: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var viewModel: SpanTestUIComponentViewModel

    var body: some View {
        TestScreenButtonView(viewModel: viewModel)
            .onAppear {
                viewModel.spanExporter = spanExporter
            }
    }
}
