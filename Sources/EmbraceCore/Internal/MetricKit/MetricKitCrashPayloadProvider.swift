//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

protocol MetricKitCrashPayloadListener: AnyObject {
    func didReceive(payload: Data, signal: Int, sessionId: SessionIdentifier?)
}

protocol MetricKitCrashPayloadProvider: AnyObject {
    func add(listener: MetricKitCrashPayloadListener)
}
