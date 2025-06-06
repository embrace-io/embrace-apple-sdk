//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

protocol MetricKitCrashPayloadListener: AnyObject {
    func didReceive(payload: Data, signal: Int, sessionId: SessionIdentifier?)
}

protocol MetricKitHangPayloadListener: AnyObject {
    func didReceive(payload: Data, startTime: Date, endTime: Date)
}

protocol MetricKitPayloadProvider: AnyObject {
    func add(listener: MetricKitCrashPayloadListener)
    func add(listener: MetricKitHangPayloadListener)
}
