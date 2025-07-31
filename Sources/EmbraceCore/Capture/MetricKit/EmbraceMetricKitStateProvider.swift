//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

protocol EmbraceMetricKitStateProvider: AnyObject {
    var isMetricKitEnabled: Bool { get }
    var isMetricKitCrashCaptureEnabled: Bool { get }
    var metricKitCrashSignals: [Int] { get }
    var isMetricKitHangCaptureEnabled: Bool { get }
}
