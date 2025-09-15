//
//  SwiftUITestsLoadedPropertyView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUITestsLoadedPropertyView: View {
    @Binding var loadedState: Bool
    let toggleIdentifier: String

    init(loadedState: Binding<Bool>, toggleIdentifier: String? = nil) {
        _loadedState = loadedState
        self.toggleIdentifier = toggleIdentifier ?? UUID().uuidString
    }

    var body: some View {
        Toggle(isOn: $loadedState) {
            Text("Produce Content Complete Span")
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSteel)
        }
        .tint(.embracePurple)
        .accessibilityIdentifier(toggleIdentifier)
    }
}

#Preview {
    @Previewable @State var loadedState: Bool = false
    return SwiftUITestsLoadedPropertyView(loadedState: $loadedState)
}
