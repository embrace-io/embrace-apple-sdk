//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import EmbraceIO
import EmbraceCommonInternal

struct LoggingView: View {
    @State private var logMessage: String = "This is the log message..."
    @State private var severity: Int = LogSeverity.info.rawValue
    @State private var behavior: Int = StackTraceBehavior.default.rawValue
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var attributes: [String: String] = [:]
    @State private var shouldCleanUp: Bool = false

    private let severities: [LogSeverity] = {
        [.info, .warn, .error]
    }()

    private let behaviors: [StackTraceBehavior] = {
        [.default, .notIncluded]
    }()

    var body: some View {
        VStack(alignment: .center) {
            VStack(alignment: .leading) {
                TextField("Message", text: $logMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                VStack(alignment: .leading) {
                    Text("Severity")
                        .bold()
                    Picker("Severity", selection: $severity) {
                        ForEach(severities, id: \.rawValue) {
                            Text($0.text)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }
                .padding(.vertical)

                VStack(alignment: .leading) {
                    Text("Stacktrace Behavior").bold()
                    Picker("Stacktrace Behavior", selection: $behavior) {
                        ForEach(behaviors, id: \.rawValue) {
                            Text($0.asString())
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }

                AttributesView(key: $key, value: $value, attributes: $attributes)
            }.padding()
            Toggle(isOn: $shouldCleanUp) {
                Text("Should clean up fields?")
            }.padding(.horizontal)
                .tint(Color.blue)
            Button {
                executeLog()
            } label: {
                Text("Execute Log")
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .font(.title3)
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }.navigationTitle("Logging")
    }
}

private extension LoggingView {
    func calculateCellWidth(basedOnProxy geometryProxy: GeometryProxy) -> Double {
        let fulldWidth = geometryProxy.size.width
        let insets = geometryProxy.safeAreaInsets.leading + geometryProxy.safeAreaInsets.trailing
        let availableSpace = fulldWidth - insets
        return availableSpace / 2.0
    }

    func executeLog() {
        guard !logMessage.isEmpty else {
            print("Cant log empty message")
            return
        }
        guard let severity = LogSeverity(rawValue: severity) else {
            print("Wrong severity number")
            return
        }
        guard let behavior = StackTraceBehavior(rawValue: behavior) else {
            print("Wrong behavior")
            return
        }
        Embrace.client?.log(logMessage, severity: severity, attributes: attributes, stackTraceBehavior: behavior)
        cleanUpFields()
    }

    func cleanUpFields() {
        guard shouldCleanUp else {
            return
        }
        logMessage = ""
        key = ""
        value = ""
        attributes = [:]
    }
}

#Preview {
    LoggingView()
}
