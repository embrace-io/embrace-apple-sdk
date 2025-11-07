//
//  EmbraceButton.swift
//  tvosTestApp
//
//

import SwiftUI

struct EmbraceButton: View {
    let title: String
    var accessibilityLabel: String = ""
    let action: @MainActor() -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.embraceFont(size: 30))
                .foregroundStyle(.embraceSilver)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    EmbraceButton(title: "Title", accessibilityLabel: "Label") {
        print("Button Action")
    }
}
