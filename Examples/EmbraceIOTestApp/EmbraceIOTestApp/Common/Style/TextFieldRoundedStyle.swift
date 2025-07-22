//
//  TextFieldRoundedStyle.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct RoundedStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .foregroundStyle(.white.opacity(0.1))
            }
    }
}
