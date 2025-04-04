//
//  LoggingTestsSeverityTypeView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

struct LoggingTestsSeverityTypeView: View {
    @Binding var logSeverity: LogSeverity
    var body: some View {
        Picker("", selection: $logSeverity) {
            ForEach(LogSeverity.allCases, id: \.self) { option in
                Text(option.text)
                    .accessibilityIdentifier(identifier(for: option))
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }

    private func identifier(for severity: LogSeverity) -> String {
        switch severity {
        case .trace:
            return "LogSeverity_Trace"
        case .debug:
            return "LogSeverity_Debug"
        case .info:
            return "LogSeverity_Info"
        case .warn:
            return "LogSeverity_Warn"
        case .error:
            return "LogSeverity_Error"
        case .fatal:
            return "LogSeverity_Fatal"
        }
    }
}

#Preview {
    @Previewable @State var severity: LogSeverity = .debug
    LoggingTestsSeverityTypeView(logSeverity: $severity)
}
