//
//  EmbraceLogo.swift
//  tvosTestApp
//
//

import SwiftUI

struct EmbraceLogo: View {
    var body: some View {
        HStack {
            Image(.embraceLogo)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .colorMultiply(.embraceYellow)
            Text("embrace")
                .font(.embraceFont(size: 80))
                .foregroundStyle(.embraceYellow)
        }
    }
}

#Preview {
    EmbraceLogo()
}
