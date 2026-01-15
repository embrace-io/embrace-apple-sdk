//
//  Embrace_watchOS_TestAppApp.swift
//  Embrace-watchOS-TestApp Watch App
//
//  Created by Fernando Draghi on 09/01/2026.
//

import EmbraceIO
import SwiftUI

@main
struct Embrace_watchOS_TestApp_Watch_AppApp: App {
    init() {
        _ = try? Embrace.setup(options: .init(appId: "wby8w")).start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
