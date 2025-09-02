//
//  EmbraceInitScreenForceStateView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct EmbraceInitScreenForceStateView: View {
    @Binding var forceInitState: EmbraceInitForceState
    var body: some View {
        Picker("", selection: $forceInitState) {
            ForEach(EmbraceInitForceState.allCases, id: \.self) { option in
                Text(option.text)
                    .accessibilityIdentifier(option.identifier)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }
}

#Preview {
    @Previewable @State var forceState: EmbraceInitForceState = .off
    return EmbraceInitScreenForceStateView(forceInitState: $forceState)
}
