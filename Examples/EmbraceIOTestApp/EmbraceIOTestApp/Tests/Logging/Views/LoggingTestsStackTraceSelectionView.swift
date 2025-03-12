//
//  LoggingTestsStackTraceSelectionView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

struct LoggingTestsStackTraceSelectionView: View {
    @Binding var stacktraceBehavior: StackTraceBehavior
    var body: some View {
        Picker("", selection: $stacktraceBehavior) {
            ForEach(StackTraceBehavior.allCases, id: \.self) { option in
                Text(option.text)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }
}

#Preview {
    LoggingTestsStackTraceSelectionView(stacktraceBehavior: .constant(.default))
}
