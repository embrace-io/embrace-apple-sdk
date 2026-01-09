//
//  ContentView.swift
//  Embrace-watchOS-TestApp Watch App
//
//  Created by Fernando Draghi on 09/01/2026.
//

import EmbraceIO
import SwiftUI

struct ContentView: View {
    init() {
        _ = try? Embrace.setup(options: .init(appId: "ejqby")).start()
    }

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
