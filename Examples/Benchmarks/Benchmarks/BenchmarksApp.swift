//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI
import os

@main
struct BenchmarksApp: App {

    init() {
        // no-op testing
        guard ProcessInfo.processInfo.environment["noop"] == nil else {
            return
        }

        // optional storage seeding, done before measuring
        if let value = ProcessInfo.processInfo.environment["EMBSeedMetadataCount"], let count = Int(value) {
            StorageSeeder.seedMetadata(count: count, appId: "bench")
        }

        let signposter = OSSignposter(subsystem: "io.embrace.benchmarks", category: "startup")

        do {
            let setupState = signposter.beginInterval("setup")
            let embrace = try Embrace.setup(
                options: Embrace.Options(
                    appId: "bench"
                )
            )
            signposter.endInterval("setup", setupState)

            let startState = signposter.beginInterval("start")
            try embrace.start()
            signposter.endInterval("start", startState)
        } catch {}
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
