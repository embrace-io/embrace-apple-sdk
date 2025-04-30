//
//  LoggingTestLogMessageUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct LoggingTestLogMessageUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var logExporter: TestLogRecordExporter {
        dataCollector.logExporter
    }
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
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
                .accessibilityIdentifier("LogTests_LogMessage")
            Section("Severity Type") {
                LoggingTestsSeverityTypeView(logSeverity: $viewModel.logSeverity)
            }
            Section("Stack Trace") {
                LoggingTestsStackTraceSelectionView(stacktraceBehavior: $viewModel.stacktraceBehavior)
            }
            Section("Custom File Attachment") {
                LoggingTestsAttachmentView(addAttachment: $viewModel.includeAttachment, attachmentSize: $viewModel.attachmentSize)
            }
            Section("Log Attributes") {
                LoggingTestsLogAttributesView { key, value in
                    viewModel.addLogAttribute(key: key, value: value)
                }
            }
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.logExporter = logExporter
                }
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    LoggingTestLogMessageUIComponent(dataModel: LoggingTestScreenDataModel.logMessage)
        .environment(dataCollector)
}
