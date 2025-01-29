//
//  MetadataTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct MetadataTestScreen: View {
    @EnvironmentObject var spanExporter: TestSpanExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    MetadataSetupTestUIComponent()
                        .environmentObject(spanExporter)
                    MetadataStartTestUIComponent()
                        .environmentObject(spanExporter)
                }
            }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    MetadataTestScreen()
        .environmentObject(spanExporter)
}
