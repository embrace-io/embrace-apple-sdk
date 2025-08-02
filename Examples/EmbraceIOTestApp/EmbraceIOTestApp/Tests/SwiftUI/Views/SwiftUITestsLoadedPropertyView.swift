//
//  SwiftUITestsLoadedPropertyView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUITestsLoadedPropertyView: View {
    @Binding var loadedState: SwiftUITestsLoadedState
    var body: some View {
        Picker("", selection: $loadedState) {
            ForEach(SwiftUITestsLoadedState.allCases, id: \.self) { option in
                Text(option.text)
                    .accessibilityIdentifier(option.identifier)
                    .font(.embraceFont(size: 12))
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }
}

#Preview {
    @State var loadedState: SwiftUITestsLoadedState = .dontInclude
    return SwiftUITestsLoadedPropertyView(loadedState: $loadedState)
}
