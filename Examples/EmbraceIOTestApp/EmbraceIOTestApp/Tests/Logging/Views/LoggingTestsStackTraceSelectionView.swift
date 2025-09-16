//
//  LoggingTestsStackTraceSelectionView.swift
//  EmbraceIOTestApp
//
//

import EmbraceCommonInternal
import SwiftUI

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
        case .main:
            return "stackTraceBehavior_main"
        case .custom:
            return "stackTraceBehavior_custom"
        }
    }
}

#Preview {
    @Previewable @State var behavior: StackTraceBehavior = .default
    return LoggingTestsStackTraceSelectionView(stacktraceBehavior: $behavior)
}
