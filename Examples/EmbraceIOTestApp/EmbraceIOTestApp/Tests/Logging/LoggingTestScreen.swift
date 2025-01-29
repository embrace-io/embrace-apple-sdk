//
//  LoggingTestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct LoggingTestScreen: View {
    @EnvironmentObject var logExporter: TestLogRecordExporter
    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    LoggingTestLogMessageUIComponent()
                        .environmentObject(logExporter)
                }
            }
        }
    }
}

#Preview {
    let logExporter = TestLogRecordExporter()
    LoggingTestScreen()
        .environmentObject(logExporter)
}
