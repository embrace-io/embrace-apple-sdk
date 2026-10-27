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
            // setup and start are a single public call
            let startState = signposter.beginInterval("start")
            try EmbraceIO.start(options: .withAppId("bench"))
            signposter.endInterval("start", startState)
        } catch {}
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
