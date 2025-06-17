//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import MetricKit
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

@objc class MetricKitHandler: NSObject, MetricKitPayloadProvider {

    private var _crashListeners = EmbraceMutex<[MetricKitCrashPayloadListener]>([])
    var crashListeners: [MetricKitCrashPayloadListener] {
        _crashListeners.safeValue
    }

    private var _hangListeners = EmbraceMutex<[MetricKitHangPayloadListener]>([])
    var hangListeners: [MetricKitHangPayloadListener] {
        _hangListeners.safeValue
    }

    @ThreadSafe
    var lastSession: EmbraceSession?

    let sessionLinkGracePeriod: TimeInterval = 5

    func install() {
#if !os(tvOS)
        MXMetricManager.shared.add(self)
#endif
    }

    func uninstall() {
#if !os(tvOS)
        MXMetricManager.shared.remove(self)
#endif
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
            sendCrash(payload: crash.data, signal: crash.signal, sessionId: sessionId)
        }

        for hang in payload.hangs {
            sendHang(payload: hang, startTime: payload.startTime, endTime: payload.endTime)
        }
    }

    func add(listener: any MetricKitCrashPayloadListener) {
        _crashListeners.withLock {
            $0.append(listener)
        }
    }

    func add(listener: any MetricKitHangPayloadListener) {
        _hangListeners.withLock {
            $0.append(listener)
        }
    }

    func sendCrash(payload: Data, signal: Int, sessionId: SessionIdentifier?) {
        for listener in crashListeners {
            listener.didReceive(payload: payload, signal: signal, sessionId: sessionId)
        }
    }

    func sendHang(payload: Data, startTime: Date, endTime: Date) {
        for listener in hangListeners {
            listener.didReceive(payload: payload, startTime: startTime, endTime: endTime)
        }
    }
}

#if !os(tvOS)
extension MetricKitHandler: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // noop for now
    }

    @available(iOS 14.0, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            handleDiagnostic(payload)
            handlePayload(MetricKitDiagnosticPayload(payload: payload))
        }
    }
    
    @available(iOS 14.0, *)
    private func handleDiagnostic(_ payload: MXDiagnosticPayload) {
        guard let crashes = payload.crashDiagnostics else { return }
        for crash in crashes {
            handleCrash(crash, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
        }
    }
    
    private func _match(on: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        if let match = regex.firstMatch(in: on, range: NSRange(on.startIndex..., in: on)) {
            let range = match.range(at: 1)
            if let foundRange = Range(range, in: on) {
                return String(on[foundRange])
            }
        }
        return nil
    }
    
    @available(iOS 14.0, *)
    private func handleCrash(_ crash: MXCrashDiagnostic, timeStampBegin: Date, timeStampEnd: Date) {
        
        var attributes: [String: String] = [:]
        
        attributes["_WARNING_"] = "Data is not for this session"
        
        attributes["mk.crash.timeStampBegin"] = String(timeStampBegin.timeIntervalSince1970)
        attributes["mk.crash.timeStampEnd"] = String(timeStampEnd.timeIntervalSince1970)
        
        if let value = crash.terminationReason {
            attributes["mk.crash.terminationReason"] = value
            attributes["mk.crash.terminationCode"] = _match(on: value, pattern: "code:(\\S+)")?.lowercased()
        }
        if let value = crash.exceptionCode as? Int {
            attributes["mk.crash.exceptionCode"] = String(value)
        }
        if let value = crash.exceptionType as? Int {
            attributes["mk.crash.exceptionType"] = String(value)
        }
        if let value = crash.signal as? Int {
            attributes["mk.crash.signal"] = String(value)
        }
        if let value = crash.virtualMemoryRegionInfo {
            attributes["mk.crash.virtualMemoryRegionInfo"] = value
        }
        if let value = crash.virtualMemoryRegionInfo {
            attributes["mk.crash.virtualMemoryRegionInfo"] = value
        }
        
        if #available(iOS 17.0, *) {
            if let reason = crash.exceptionReason {
                attributes["mk.crash.exception.className"] = reason.className
                attributes["mk.crash.exception.composedMessage"] = reason.composedMessage
                attributes["mk.crash.exception.exceptionName"] = reason.exceptionName
                attributes["mk.crash.exception.exceptionType"] = reason.exceptionType
            }
        }
        
        let time = Date()
        Embrace.client?.otel.buildSpan(name: "MXCrashDiagnostic", type: .performance, attributes: attributes)
            .setStartTime(time: time)
            .startSpan()
            .end(time: time)
        
    }
}
#endif

// abstraction for injection during tests
class MetricKitDiagnosticPayload {
    let startTime: Date
    let endTime: Date
    let crashes: [MetricKitCrashData]
    let hangs: [Data]

    init(startTime: Date, endTime: Date, crashes: [MetricKitCrashData], hangs: [Data]) {
        self.startTime = startTime
        self.endTime = endTime
        self.crashes = crashes
        self.hangs = hangs
    }

#if !os(tvOS)
    @available(iOS 14.0, *)
    init(payload: MXDiagnosticPayload) {
        self.startTime = payload.timeStampBegin
        self.endTime = payload.timeStampEnd
        self.crashes = payload.crashDiagnostics?.map({
            MetricKitCrashData(data: $0.jsonRepresentation(), signal: $0.signal?.intValue ?? 0)
        }) ?? []
        self.hangs = payload.hangDiagnostics?.map { $0.jsonRepresentation() } ?? []
    }
#endif
}

struct MetricKitCrashData {
    let data: Data
    let signal: Int
}
