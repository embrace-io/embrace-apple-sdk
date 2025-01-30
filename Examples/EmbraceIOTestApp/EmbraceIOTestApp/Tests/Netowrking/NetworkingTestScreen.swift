//
//  NetworkingTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct NetworkingTestScreen: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    NetworkingTestUIComponent()
                        .environmentObject(spanExporter)
                }
            }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    NetworkingTestScreen()
        .environmentObject(spanExporter)
}
