//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore

class MockMetricKitStateProvider: EmbraceMetricKitStateProvider {
    var isMetricKitInternalMetricsCaptureEnabled: Bool = true
    var isMetricKitEnabled: Bool = true
    var isMetricKitCrashCaptureEnabled: Bool = true
    var metricKitCrashSignals: [Int] = [9]
    var isMetricKitHangCaptureEnabled: Bool = true
}
