//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation

@testable import EmbraceCore

class MockMetricKitCrashPayloadListener: MetricKitCrashPayloadListener {

    private(set) var didReceivePayload: Bool = false
    private(set) var payloadData: Data? = nil
    private(set) var payloadSignal: Int? = nil
    private(set) var session: EmbraceSession? = nil
    var sessionId: EmbraceIdentifier? { session?.id }

    func didReceive(payload: Data, signal: Int, session: EmbraceSession?) {
        didReceivePayload = true
        payloadData = payload
        payloadSignal = signal
        self.session = session
    }
}
