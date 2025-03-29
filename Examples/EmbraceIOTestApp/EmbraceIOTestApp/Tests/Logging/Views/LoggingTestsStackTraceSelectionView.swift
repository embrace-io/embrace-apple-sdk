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
                    .accessibilityIdentifier(identifier(for: option))
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }

    private func identifier(for behavior: StackTraceBehavior) -> String {
        switch behavior {
        case .default:
            return "stackTraceBehavior_Default"
        case .notIncluded:
            return "stackTraceBehavior_notIncluded"
        case .custom:
            return "stackTraceBehavior_custom"
        }
    }
}

#Preview {
    @Previewable @State var behavior: StackTraceBehavior = .default
    LoggingTestsStackTraceSelectionView(stacktraceBehavior: $behavior)
}
