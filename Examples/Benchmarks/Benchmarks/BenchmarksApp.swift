//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI

@main
struct BenchmarksApp: App {

    private let environment = ProcessInfo.processInfo.environment

    init() {
        // no-op testing
        guard environment["noop"] == nil else {
            return
        }

        do {
            try EmbraceIO.start(options: .withAppId("bench", captureServices: captureServices()))
        } catch {}
    }

    /// Default services, plus the opt-in ones requested by the launch environment:
    /// - `EMBHang=1`: `HangCaptureService`
    /// - `EMBSmoothness=1`: `SmoothnessCaptureService`
    private func captureServices() -> EmbraceIO.CaptureServicesOptions {
        let builder = CaptureServicesOptionsBuilder().addDefaults()
        if environment["EMBHang"] == "1" {
            _ = builder.addHangCaptureService()
        }
        if environment["EMBSmoothness"] == "1" {
            _ = builder.addSmoothnessCaptureService()
        }
        return builder.build()
    }

    var body: some Scene {
        WindowGroup {
            // `EMBBenchmarkScreen` launches straight into a smoothness overhead screen.
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
