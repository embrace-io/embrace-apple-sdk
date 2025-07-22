//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

@testable import EmbraceCore

class MockMetricKitCrashPayloadListener: MetricKitCrashPayloadListener {

    private(set) var didReceivePayload: Bool = false
    private(set) var payloadData: Data? = nil
    private(set) var payloadSignal: Int? = nil
    private(set) var sessionId: SessionIdentifier? = nil

    func didReceive(payload: Data, signal: Int, sessionId: SessionIdentifier?) {
        didReceivePayload = true
        payloadData = payload
        payloadSignal = signal
        self.sessionId = sessionId
    }
}
