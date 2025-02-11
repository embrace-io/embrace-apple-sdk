//
//  MetadataTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct MetadataTestScreen: View {
    @Environment(TestSpanExporter.self) private var spanExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    MetadataSetupTestUIComponent()
                        .environment(spanExporter)
                    MetadataStartTestUIComponent()
                        .environment(spanExporter)
                }
            }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    MetadataTestScreen()
        .environment(spanExporter)
}
