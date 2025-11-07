//
//  MainScreen.swift
//  Embrace-tvOS-TestApp
//
//

import SwiftUI

struct MainScreen: View {
    var body: some View {
        VStack {
            Button {

            } label: {
                VStack {
                    Text("Button 1")
                    Hints(buttonName: "1")
                }
            }

            Button {

            } label: {
                VStack {
                    Text("Button 2")
                    Hints(buttonName: "2")
                }
            }
        }
        .padding()
    }
}

struct Hints: View {
    @Environment(\.isFocused) var isFocused: Bool
    let buttonName: String
    var text: String {
        isFocused ? "Here's a hint for button: \(buttonName)" : ""
    }
    var body: some View {
        Text(text)
            .opacity(isFocused ? 1.0 : 0)
    }
}

#Preview {
    MainScreen()
}
