//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

protocol MetricKitCrashPayloadListener: AnyObject {
    /// - Parameter session: The session part the payload was linked to, if any. The whole record is
    ///   passed (instead of just its id) so the crash log can be stamped with the part id, the user
    ///   session id, and the metadata of that user session.
    func didReceive(payload: Data, signal: Int, session: EmbraceSession?)
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
