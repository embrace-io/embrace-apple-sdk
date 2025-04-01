//
//  EmbraceIOTestAppApp.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO
import OpenTelemetrySdk

@main
struct EmbraceIOTestAppApp: App {
    let spanExporter = TestSpanExporter()
    let logExporter = TestLogRecordExporter()
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .preferredColorScheme(.dark)
                    .environment(spanExporter)
                    .environment(logExporter)
            }
        }
    }
}
