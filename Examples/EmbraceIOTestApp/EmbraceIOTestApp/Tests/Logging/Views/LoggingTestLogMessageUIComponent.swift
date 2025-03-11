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
    @State private var attributeKey: String = ""
    @State private var attributeValue: String = ""
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
            Section("Log Attributes") {
                VStack {
                    HStack {
                        Spacer()
                        Text("Key")
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        TextField("A key", text: $attributeKey)
                            .font(.embraceFont(size: 18))
                            .foregroundStyle(.embraceSilver)
                            .padding([.leading, .trailing,], 5)
                            .textFieldStyle(RoundedStyle())
                    }
                    HStack {
                        Spacer()
                        Text("Value")
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        TextField("A value", text: $attributeValue)
                            .font(.embraceFont(size: 18))
                            .foregroundStyle(.embraceSilver)
                            .padding([.leading, .trailing,], 5)
                            .textFieldStyle(RoundedStyle())
                    }
                    Button {
                        viewModel.addLogAttribute(key: attributeKey, value: attributeValue)
                        attributeKey = ""
                        attributeValue = ""
                    } label: {
                        Text("Insert Attribute")
                            .frame(height: 40)
                    }
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
    let logExporter = TestLogRecordExporter()
    LoggingTestLogMessageUIComponent(dataModel: LoggingTestScreenDataModel.errorLogMessage)
        .environment(logExporter)
}
