//
//  TestLogScreenButtonView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestLogScreenButtonView: View {
    @Environment(TestLogRecordExporter.self) private var logRecordExporter
    @State var viewModel: LogTestUIComponentViewModel

    var body: some View {
        TestScreenButtonView(viewModel: viewModel)
            .onAppear {
                viewModel.logExporter = logRecordExporter
            }
    }
}
