//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

@testable import EmbraceCore

class MockMetricKitHangPayloadListener: MetricKitHangPayloadListener {

    private(set) var didReceivePayload: Bool = false
    private(set) var payloadData: Data? = nil
    private(set) var startTime: Date? = nil
    private(set) var endTime: Date? = nil

    func didReceive(payload: Data, startTime: Date, endTime: Date) {
        didReceivePayload = true
        payloadData = payload
        self.startTime = startTime
        self.endTime = endTime
    }
}
