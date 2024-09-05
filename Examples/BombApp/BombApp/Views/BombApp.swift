//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

@main
struct BombApp: App {
    @UIApplicationDelegateAdaptor(BombAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                BombView()
            }
        }
    }
}
