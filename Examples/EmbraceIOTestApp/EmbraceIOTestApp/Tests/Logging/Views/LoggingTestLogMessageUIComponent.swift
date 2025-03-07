//
//  LoggingTestLogMessageUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct LoggingTestLogMessageUIComponent: View {
    @Environment(TestLogRecordExporter.self) private var logExporter
    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: LoggingTestMessageViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Logging Message")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("Enter a message to log", text: $viewModel.message)
                .font(.embraceFont(size: 18))
                .backgroundStyle(.red)
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
            Section("Severity Type") {
                Picker("", selection: $viewModel.logSeverity) {
                    ForEach(viewModel.logSeverities, id: \.self) { option in
                        Text(option.text)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 20)
            }
            Section("Stack Trace") {
                Picker("", selection: $viewModel.stacktraceBehavior) {
                    ForEach(viewModel.stacktraceBehaviors, id: \.self) { option in
                        Text(option.text)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 20)
            }
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.logExporter = logExporter
                }
        }
    }
}

#Preview {
    let logExporter = TestLogRecordExporter()
    LoggingTestLogMessageUIComponent(dataModel: LoggingTestScreenDataModel.errorLogMessage)
        .environment(logExporter)
}
