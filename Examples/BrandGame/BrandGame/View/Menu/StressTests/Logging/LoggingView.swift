//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceIO
import SwiftUI

struct LoggingView: View {
    @State private var logMessage: String = "This is the log message..."
    @State private var severity: Int = LogSeverity.info.rawValue
    @State private var behavior: Int = Behavior.default.rawValue
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var attributes: [String: String] = [:]
    @State private var shouldCleanUp: Bool = false

    private let severities: [LogSeverity] = {
        [.info, .warn, .error]
    }()

    private let behaviors: [Behavior] = {
        [.default, .notIncluded, .custom]
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

extension LoggingView {
    fileprivate func calculateCellWidth(basedOnProxy geometryProxy: GeometryProxy) -> Double {
        let fulldWidth = geometryProxy.size.width
        let insets = geometryProxy.safeAreaInsets.leading + geometryProxy.safeAreaInsets.trailing
        let availableSpace = fulldWidth - insets
        return availableSpace / 2.0
    }

    fileprivate func executeLog() {
        guard !logMessage.isEmpty else {
            print("Cant log empty message")
            return
        }
        guard let severity = LogSeverity(rawValue: severity) else {
            print("Wrong severity number")
            return
        }
        guard let stackTraceBehavior = try? getStackTraceBehavior() else {
            print("Wrong stacktrace behavior")
            return
        }
        Embrace.client?.log(
            logMessage,
            severity: severity,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior
        )
        cleanUpFields()
    }

    fileprivate func getStackTraceBehavior() throws -> StackTraceBehavior {
        switch Behavior(rawValue: behavior) {
        case .default:
            return .default
        case .notIncluded:
            return .notIncluded
        case .custom:
            return .custom(
                try EmbraceStackTrace(
                    frames: [
                        "0 BrandGame 0x0000000005678def [SomeClass method] + 48",
                        "1 Random Library 0x0000000001234abc [Random init]",
                        "2 \(UUID().uuidString) 0x0000000001234abc [\(UUID().uuidString) \(UUID().uuidString))]",
                    ])
            )
        case .none:
            throw NSError(domain: "BrandGame", code: -1, userInfo: [:])
        }
    }

    fileprivate func cleanUpFields() {
        guard shouldCleanUp else {
            return
        }
        logMessage = ""
        key = ""
        value = ""
        attributes = [:]
    }
}

extension LoggingView {
    enum Behavior: Int {
        case notIncluded
        case `default`
        case custom

        static func from(_ stackTraceBehavior: StackTraceBehavior) -> Self {
            switch stackTraceBehavior {
            case .notIncluded:
                return .notIncluded
            case .default:
                return .default
            case .custom(_):
                return .custom
            }
        }

        func asString() -> String {
            return switch self {
            case .notIncluded:
                "Not included"
            case .default:
                "Default"
            case .custom:
                "Custom"
            }
        }
    }
}

#Preview {
    LoggingView()
}
