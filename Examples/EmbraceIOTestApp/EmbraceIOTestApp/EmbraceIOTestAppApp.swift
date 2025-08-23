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

    init() {
        let env = ProcessInfo.processInfo.environment
        if env["UITestMode"] == "YES" {
            if env["DisableAnimations"] == "YES" {
                UIView.setAnimationsEnabled(false)
            }
        }
    }

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
