//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension Embrace: EmbraceMetricKitStateProvider {
    var isMetricKitEnabled: Bool {
        config.isMetrickKitEnabled
    }

    var isMetricKitCrashCaptureEnabled: Bool {
        config.isMetricKitCrashCaptureEnabled
    }

    var metricKitCrashSignals: [Int] {
        config.metricKitCrashSignals.map { $0.rawValue }
    }

    var isMetricKitHangCaptureEnabled: Bool {
        config.isMetricKitHangCaptureEnabled
    }

    var isMetricKitInternalMetricsCaptureEnabled: Bool {
        config.isMetricKitInternalMetricsCaptureEnabled
    }
}
