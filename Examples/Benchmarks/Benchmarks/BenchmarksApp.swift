//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

@_spi(Private) import EmbraceCore
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

    /// Default services except `SmoothnessCaptureService`, plus the ones requested by the launch
    /// environment:
    /// - `EMBHang=1`: `HangCaptureService`
    /// - `EMBSmoothness=1`: `SmoothnessCaptureService`, running whatever the remote config says
    private func captureServices() -> EmbraceIO.CaptureServicesOptions {
        // Smoothness is a default service but gated by remote config, so it's removed here and only
        // added back, forced on, for the arm that measures it. The Off arm then has no service at all.
        let builder = CaptureServicesOptionsBuilder().addDefaults().remove(ofType: SmoothnessCaptureService.self)
        if environment["EMBHang"] == "1" {
            _ = builder.addHangCaptureService()
        }
        if environment["EMBSmoothness"] == "1" {
            // Added as an instance, rather than with `addSmoothnessCaptureService()`, so the
            // benchmark screens can show whether it is really counting frames, and so it can ignore
            // the remote config: the bench app is outside any rollout.
            let service = SmoothnessCaptureService(ignoresRemoteConfig: true)
            SmoothnessProbe.service = service
            _ = builder.add(service)
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
