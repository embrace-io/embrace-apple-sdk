//
//  ContentView.swift
//  Embrace-tvOS-TestApp
//
//  Created by Fernando Draghi on 14/10/2025.
//

import SwiftUI
import EmbraceIO
import EmbraceCrash

struct ContentView: View {
    init() {
        _ = try? Embrace.setup(options: .init(appId: "ejqby")).start()
    }
    var body: some View {
        VStack {
            Button {
                
            } label: {
                Text("Button 1")
            }
            
            Button {
                
            } label: {
                Text("Button 2")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
