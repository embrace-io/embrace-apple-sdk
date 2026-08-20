//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI

@main
struct BenchmarksApp: App {

    init() {
        // no-op testing
        guard ProcessInfo.processInfo.environment["noop"] == nil else {
            return
        }

        do {
            try EmbraceIO.start(options: .withAppId("bench"))
        } catch {}
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
