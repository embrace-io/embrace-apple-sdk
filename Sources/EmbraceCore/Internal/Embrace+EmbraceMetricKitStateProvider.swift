//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

extension Embrace: EmbraceMetricKitStateProvider {
    public var isMetricKitEnabled: Bool {
        config?.isMetrickKitEnabled ?? false
    }

    public var isMetricKitCrashCaptureEnabled: Bool {
        config?.isMetricKitCrashCaptureEnabled ?? false
    }

    public var metricKitCrashSignals: [Int] {
        config?.metricKitCrashSignals.map { $0.rawValue } ?? [CrashSignal.SIGKILL.rawValue]
    }

    public var isMetricKitHangCaptureEnabled: Bool {
        config?.isMetricKitHangCaptureEnabled ?? false
    }
}
