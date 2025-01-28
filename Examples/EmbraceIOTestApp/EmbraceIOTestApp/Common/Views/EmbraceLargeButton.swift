//
//  EmbraceLargeButton.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct EmbraceLargeButton: View {
    var text: String = ""
    var enabled: Bool = true
    let buttonAction: () -> Void
    
    var body: some View {
        VStack {
            Button {
                buttonAction()
            } label: {
                ZStack {
                    Rectangle()
                        .foregroundStyle(.embraceYellow.opacity(enabled ? 1.0 : 0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    Text(text)
                        .foregroundStyle(.embraceLead)
                        .font(.embraceFontLight(size: 30))
                }
            }
        }
        .disabled(!enabled)
        .frame(height: 60)
        .ignoresSafeArea()
    }
}

#Preview {
    VStack {
        EmbraceLargeButton(text: "Try Embrace", enabled: true, buttonAction: {})
        EmbraceLargeButton(text: "Try Embrace", enabled: false, buttonAction: {})
    }
}
