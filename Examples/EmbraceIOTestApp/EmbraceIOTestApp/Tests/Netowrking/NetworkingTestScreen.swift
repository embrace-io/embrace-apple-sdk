//
//  NetworkingTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct NetworkingTestScreen: View {
    @Environment(TestSpanExporter.self) private var spanExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    NetworkingTestUIComponent()
                        .environment(spanExporter)
                }
            }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    NetworkingTestScreen()
        .environment(spanExporter)
}
