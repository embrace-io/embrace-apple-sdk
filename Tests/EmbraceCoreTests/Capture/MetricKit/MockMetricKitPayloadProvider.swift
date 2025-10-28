//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore

class MockMetricKitPayloadProvider: MetricKitPayloadProvider {

    var didCallAddCrashListener: Bool = false
    var lastCrashListener: AnyObject? = nil
    func add(listener: any MetricKitCrashPayloadListener) {
        didCallAddCrashListener = true
        lastCrashListener = listener
    }

    var didCallAddHangListener: Bool = false
    var lastHangListener: AnyObject? = nil
    func add(listener: any MetricKitHangPayloadListener) {
        didCallAddHangListener = true
        lastHangListener = listener
    }

    var didCallAddMetricsListener: Bool = false
    var lastMetricsListener: AnyObject? = nil
    func add(listener: any MetricKitMetricsPayloadListener) {
        didCallAddMetricsListener = true
        lastMetricsListener = listener
    }
}
