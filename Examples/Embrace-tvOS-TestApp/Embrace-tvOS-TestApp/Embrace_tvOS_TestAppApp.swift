//
//  Embrace_tvOS_TestAppApp.swift
//  Embrace-tvOS-TestApp
//
//

import EmbraceConfiguration
import EmbraceIO
import SwiftUI

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
