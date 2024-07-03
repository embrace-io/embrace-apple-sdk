//
//  ContentView.swift
//  BombApp
//
//  Created by Ariel Demarco on 02/07/2024.
//

import SwiftUI

struct BombView: View {
    @State private var showTooltip: Bool

    init(showTooltip: Bool = false) {
        UITableView.appearance().backgroundColor = .clear
        self.showTooltip = showTooltip
    }

    var body: some View {
        VStack {
            List(Bomb.allCases, id: \.self) { option in
                Button(action: {
                    option.case.crash()
                }, label: {
                    VStack {
                        Text(option.case.title)
                    }
                }).listRowBackground(Color.clear)
            }
            .listStyle(PlainListStyle())
            .background(Color.clear)
        }
        .padding()
        .navigationTitle("BombApp")
        .toolbar {
            Button(action: {
                withAnimation(.spring()) {
                    showTooltip.toggle()
                }
            }, label: {
                Image(systemName: "info.circle")
                    .tint(.primary)
            })
            .sheet(isPresented: $showTooltip) {
                Text("""
                    Build this app using the **Release** build configuration and install it on a device.

                    Either use **Archive** or **Build** for Profiling and copy the app bundle onto the device.

                    **Debug** build configuration has disabled some compiler optimizations.
                    """)
                .background(.background)
                .foregroundColor(.primary)
                .font(.callout)
                .padding(.horizontal)
                .presentationDetents([.fraction(0.25)])
            }
        }
    }
}

#Preview {
    NavigationStack {
        BombView(showTooltip: false)
    }
}
