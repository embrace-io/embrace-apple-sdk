//
//  TestLogScreenButtonView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestLogScreenButtonView: View {
    @Environment(DataCollector.self) private var dataCollector
    private var logRecordExporter: TestLogRecordExporter {
        dataCollector.logExporter
    }
    @State var viewModel: LogTestUIComponentViewModel

    var body: some View {
        TestScreenButtonView(viewModel: viewModel)
            .onAppear {
                viewModel.logExporter = logRecordExporter
            }
    }
}
