//
//  ContentView.swift
//  Embrace-watchOS-TestApp Watch App
//
//  Created by Fernando Draghi on 09/01/2026.
//

import SwiftUI
import EmbraceIO
import EmbraceCommonInternal

struct WatchOSTestAppWelcomeScreen: View {
    var body: some View {
        VStack {
            Button {
                Embrace.client?.log("Test Log from Apple Watch", severity: .info)
            } label: {
                Text("Test Log")
            }
        }
        .padding()
    }
}

#Preview {
    WatchOSTestAppWelcomeScreen()
}
