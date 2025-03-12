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
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }
}

#Preview {
    @Previewable @State var severity: LogSeverity = .debug
    LoggingTestsSeverityTypeView(logSeverity: $severity)
}
