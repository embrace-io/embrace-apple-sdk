//
//  ViewControllerTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct ViewControllerTestScreen: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    ViewControllerTestUIComponent()
                        .environmentObject(spanExporter)
                }
            }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    ViewControllerTestScreen()
        .environmentObject(spanExporter)
}
