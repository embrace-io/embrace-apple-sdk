//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

class MockMetricKitStateProvider: EmbraceMetricKitStateProvider {
    var isMetricKitEnabled: Bool = true
    var isMetricKitCrashCaptureEnabled: Bool = true
    var metricKitCrashSignals: [Int] = [9]
    var isMetricKitHangCaptureEnabled: Bool = true
}
