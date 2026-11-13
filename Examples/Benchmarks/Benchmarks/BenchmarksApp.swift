//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

@_spi(Private) import EmbraceCore
import EmbraceIO
import SwiftUI
import os

@main
struct BenchmarksApp: App {

    private let environment = ProcessInfo.processInfo.environment

    init() {
        // no-op testing
        guard environment["noop"] == nil else {
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
            try EmbraceIO.start(options: .withAppId("bench", captureServices: captureServices()))
            signposter.endInterval("start", startState)
        } catch {}
    }

    /// Default services except `SmoothnessCaptureService`, plus the ones requested by the launch
    /// environment:
    /// - `EMBHang=1`: `HangCaptureService`
    /// - `EMBSmoothness=1`: `SmoothnessCaptureService`, running whether or not remote config enables it
    private func captureServices() -> EmbraceIO.CaptureServicesOptions {
        let builder = CaptureServicesOptionsBuilder().addDefaults().remove(ofType: SmoothnessCaptureService.self)
        if environment["EMBHang"] == "1" {
            builder.addHangCaptureService()
        }
        if environment["EMBSmoothness"] == "1" {
            // An instance, so the benchmark screens can read its frame count.
            let service = SmoothnessCaptureService(ignoresRemoteConfig: true)
            SmoothnessProbe.service = service
            builder.add(service)
        }
        return builder.build()
    }

    var body: some Scene {
        WindowGroup {
            switch environment["EMBBenchmarkScreen"] {
            case "smoothness-scroll":
                SmoothnessScrollView()
            case "smoothness-animation":
                SmoothnessAnimationView()
            default:
                ContentView()
            }
        }
    }
}
