//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

import EmbraceCore

@main
struct BrandGameApp: App {

    @State var settings: AppSettings = AppSettings()

    init() {
        do {
            try Embrace.setup(
                options: embraceOptions)

            try Embrace.client?.start()
            Embrace.client?.logLevel = .debug
            
            if ProcessInfo.processInfo.arguments.count > 1 {
                switch ProcessInfo.processInfo.arguments[1] {
                case "Metadata":
                    Embrace.client?.buildSpan(name: "Test Started for Metadata", type: .performance).startSpan().end()
                default:
                    break
                }
            }
        } catch let e {
            print("Error starting embrace \(e.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.settings, settings)
        }
    }
}
