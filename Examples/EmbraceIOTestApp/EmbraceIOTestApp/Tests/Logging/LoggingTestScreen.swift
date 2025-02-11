//
//  LoggingTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct LoggingTestScreen: View {
    @Environment(TestLogRecordExporter.self) private var logExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    LoggingTestLogMessageUIComponent()
                        .environment(logExporter)
                }
            }
        }
    }
}

#Preview {
    let logExporter = TestLogRecordExporter()
    LoggingTestScreen()
        .environment(logExporter)
}
