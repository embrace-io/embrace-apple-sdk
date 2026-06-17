//
//  ContentView.swift
//  Embrace-watchOS-TestApp Watch App
//
//  Created by Fernando Draghi on 09/01/2026.
//

import EmbraceCommonInternal
import EmbraceIO
import EmbraceSemantics
import SwiftUI

struct WatchOSTestAppWelcomeScreen: View {
    var body: some View {
        VStack {
            Button {
                EmbraceIO.shared.log("Test Log from Apple Watch", severity: .info)
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
