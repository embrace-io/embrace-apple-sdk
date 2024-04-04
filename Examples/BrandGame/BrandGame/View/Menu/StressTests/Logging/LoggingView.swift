//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import EmbraceIO
import EmbraceCommon

struct LoggingView: View {
    @State private var logMessage: String = "This is the log message..."
    @State private var severity: Int = LogSeverity.info.rawValue
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var attributes: [String: String] = [:]
    @State private var shouldCleanUp: Bool = false

    private let severities: [LogSeverity] = {
        [.info, .warn, .error]
    }()

    var body: some View {
        VStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("Logging")
                    .font(.title)
                    .bold()
                TextField("Message", text: $logMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Picker("Severity", selection: $severity) {
                    ForEach(severities, id: \.rawValue) {
                        Text($0.text)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom)
                Group {
                    Text("Attributes")
                        .font(.title3)
                        .bold()
                    HStack {
                        TextField("Key", text: $key)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Value", text: $value)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: {
                            attributes[key] = value
                            key = ""
                            value = ""
                        }, label: {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.blue)
                        })
                        .disabled(key.isEmpty || value.isEmpty)
                    }

                    GeometryReader { proxy in
                        ScrollView {
                            LazyVStack {
                                if !attributes.isEmpty {
                                    HStack {
                                        Text("Key")
                                            .bold()
                                            .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                        Text("Value")
                                            .bold()
                                            .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                    }.padding(.bottom, 8)
                                }
                                ForEach(attributes.keys.sorted(), id: \.self) { key in
                                    HStack {
                                        Text(key)
                                            .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                            .lineLimit(1)
                                        Text(attributes[key] ?? "")
                                            .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.top)
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
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
        }
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
        Embrace.client?.log(logMessage, severity: severity, attributes: attributes)
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
