//
//  LoggingTestsSeverityTypeView.swift
//  EmbraceIOTestApp
//
//

import EmbraceSemantics
import SwiftUI

struct LoggingTestsSeverityTypeView: View {
    @Binding var logSeverity: EmbraceLogSeverity
    var body: some View {
        Picker("", selection: $logSeverity) {
            ForEach(EmbraceLogSeverity.allCases, id: \.self) { option in
                Text((option == .critical ? "CRITICAL" : option.name).lowercased())
                    .accessibilityIdentifier(identifier(for: option))
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }

    private func identifier(for severity: EmbraceLogSeverity) -> String {
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
        case .critical:
            return "LogSeverity_Critical"
        }
    }
}

#Preview {
    @Previewable @State var severity: EmbraceLogSeverity = .debug
    return LoggingTestsSeverityTypeView(logSeverity: $severity)
}
