//
//  SwiftUITestsLoadedPropertyView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUITestsLoadedPropertyView: View {
    @Binding var loadedState: Bool
    var body: some View {
        Toggle(isOn: $loadedState) {
            Text("Produce Content Complete Span")
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSteel)
        }
        .tint(.embracePurple)
    }
}

#Preview {
    @State var loadedState: Bool = false
    return SwiftUITestsLoadedPropertyView(loadedState: $loadedState)
}
