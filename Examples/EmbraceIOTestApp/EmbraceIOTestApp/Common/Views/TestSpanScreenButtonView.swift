//
//  TestSpanScreenButtonView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestSpanScreenButtonView: View {
    @Environment(TestSpanExporter.self) private var spanExporter
    @State var viewModel: SpanTestUIComponentViewModel

    var body: some View {
        TestScreenButtonView(viewModel: viewModel)
            .onAppear {
                viewModel.spanExporter = spanExporter
            }
            .onChange(of: spanExporter.state) { _, _ in
                viewModel.spanExporterUpdated()
            }
            
    }
}
