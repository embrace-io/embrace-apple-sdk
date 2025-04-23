//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import MetricKit
import EmbraceCommonInternal

@objc class MetricKitHandler: NSObject, MXMetricManagerSubscriber, MetricKitCrashPayloadProvider {

    @ThreadSafe
    var listeners: [MetricKitCrashPayloadListener] = []

    @ThreadSafe
    var lastSession: EmbraceSession?

    let sessionLinkGracePeriod: TimeInterval = 5

    func install() {
        MXMetricManager.shared.add(self)
    }

    func uninstall() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // noop for now
    }

    @available(iOS 14.0, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            handlePayload(MetricKitDiagnosticPayload(payload: payload))
        }
    }

    func handlePayload(_ payload: MetricKitDiagnosticPayload) {
        // check if the payload should be linked to the latest session
        var sessionId: SessionIdentifier?

        if let session = lastSession {
            let payloadStart = payload.startTime.timeIntervalSince1970
            let payloadEnd = payload.endTime.timeIntervalSince1970
            let sessionEnd = session.endTime?.timeIntervalSince1970 ?? session.lastHeartbeatTime.timeIntervalSince1970

            let startDiff = abs(payloadStart - session.startTime.timeIntervalSince1970)
            let endDiff = abs(payloadEnd - sessionEnd)

            if startDiff <= sessionLinkGracePeriod || endDiff <= sessionLinkGracePeriod {
                sessionId = session.id
            }
        }

        for crash in payload.crashes {
            send(crashPayload: crash.data, signal: crash.signal, sessionId: sessionId)
        }
    }

    func add(listener: any MetricKitCrashPayloadListener) {
        listeners.append(listener)
    }

    func send(crashPayload: Data, signal: Int, sessionId: SessionIdentifier?) {
        for listener in listeners {
            listener.didReceive(payload: crashPayload, signal: signal, sessionId: sessionId)
        }
    }
}

// abstraction for injection during tests
class MetricKitDiagnosticPayload {
    let startTime: Date
    let endTime: Date
    let crashes: [MetricKitCrashData]

    init(startTime: Date, endTime: Date, crashes: [MetricKitCrashData]) {
        self.startTime = startTime
        self.endTime = endTime
        self.crashes = crashes
    }

    @available(iOS 14.0, *)
    init(payload: MXDiagnosticPayload) {
        self.startTime = payload.timeStampBegin
        self.endTime = payload.timeStampEnd
        self.crashes = payload.crashDiagnostics?.map({
            MetricKitCrashData(data: $0.jsonRepresentation(), signal: $0.signal?.intValue ?? 0)
        }) ?? []
    }
}

struct MetricKitCrashData {
    let data: Data
    let signal: Int
}
