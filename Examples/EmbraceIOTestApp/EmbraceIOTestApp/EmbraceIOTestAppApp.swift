//
//  EmbraceIOTestAppApp.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import OpenTelemetrySdk
import SwiftUI

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
