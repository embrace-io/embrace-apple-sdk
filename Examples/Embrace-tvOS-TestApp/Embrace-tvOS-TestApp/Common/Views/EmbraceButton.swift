//
//  EmbraceButton.swift
//  tvosTestApp
//
//

import SwiftUI

struct EmbraceButton: View {
    let title: String
    var accessibilityLabel: String = ""
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            EmbraceButtonFocusableText(title: title)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct EmbraceButtonFocusableText: View {
    @Environment(\.isFocused) var isFocused: Bool
    var title: String

    private var style: Color {
        isFocused ? .embraceLead : .embraceSilver
    }

    var body: some View {
        Text(title)
            .font(.embraceFont(size: 30))
            .foregroundStyle(style)
    }
}

#Preview {
    EmbraceButton(title: "Title", accessibilityLabel: "Label") {
        print("Button Action")
    }
}
