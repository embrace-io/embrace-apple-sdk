//
//  Embrace_tvOS_TestAppApp.swift
//  Embrace-tvOS-TestApp
//
//  Created by Fernando Draghi on 14/10/2025.
//

import SwiftUI
import EmbraceIO

@main
struct Embrace_tvOS_TestAppApp: App {
    init() {
        _ = try? Embrace.setup(options: .init(appId: "ejqby")).start()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
