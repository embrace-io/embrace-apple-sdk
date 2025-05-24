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
    let dataCollector = DataCollector(setupSwizzles: true)
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .preferredColorScheme(.dark)
                    .environment(dataCollector)
            }
        }
    }
}
