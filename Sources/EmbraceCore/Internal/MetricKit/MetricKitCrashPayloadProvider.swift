//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

protocol MetricKitCrashPayloadListener: AnyObject {
    func didReceive(payload: Data, signal: Int, sessionId: EmbraceIdentifier?)
}

protocol MetricKitHangPayloadListener: AnyObject {
    func didReceive(payload: Data, startTime: Date, endTime: Date)
}

protocol MetricKitMetricsPayloadListener: AnyObject {
    func didReceive(metric payload: Data)
}

protocol MetricKitPayloadProvider: AnyObject {
    func add(listener: MetricKitCrashPayloadListener)
    func add(listener: MetricKitHangPayloadListener)
    func add(listener: MetricKitMetricsPayloadListener)
}
