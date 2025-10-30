//
//  Embrace_tvOS_TestAppApp.swift
//  Embrace-tvOS-TestApp
//
//

import SwiftUI
import EmbraceIO
import EmbraceConfiguration

@main
struct Embrace_tvOS_TestAppApp: App {
    init() {
        
        _ = try? Embrace.setup(options: .init(appId: "ejqby")).start()
    }
    var body: some Scene {
        WindowGroup {
            LoginScreen()
        }
    }
}
