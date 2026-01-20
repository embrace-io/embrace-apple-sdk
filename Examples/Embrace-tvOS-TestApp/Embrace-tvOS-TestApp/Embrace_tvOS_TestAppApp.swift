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
    @State private var navigator = AppNavigator()

    init() {
        _ = try? Embrace.setup(options: .init(appId: "ejqby")).start()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigator.path) {
                MainScreen()
                    .environment(navigator)
                    .navigationDestination(for: AppScreens.self) { screen in
                        switch screen {
                        case .login:
                            LoginScreen()
                                .environment(navigator)
                        }
                    }
            }
        }
    }
}
