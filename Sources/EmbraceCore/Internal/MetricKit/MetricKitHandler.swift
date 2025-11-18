//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if canImport(MetricKit)
    import MetricKit
#endif

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

    private var _metricsListeners = EmbraceMutex<[MetricKitMetricsPayloadListener]>([])
    var metricsListeners: [MetricKitMetricsPayloadListener] {
        _metricsListeners.safeValue
    }

    private let _lastSession = EmbraceMutex<EmbraceSession?>(nil)
    public var lastSession: EmbraceSession? {
        get { _lastSession.safeValue }
        set { _lastSession.safeValue = newValue }
    }

    let sessionLinkGracePeriod: TimeInterval = 5

    func install() {
        #if !os(tvOS) && !os(macOS) && !os(watchOS)
            MXMetricManager.shared.add(self)
        #endif
    }

    func uninstall() {
        #if !os(tvOS) && !os(macOS) && !os(watchOS)
            MXMetricManager.shared.remove(self)
        #endif
    }

    func handlePayload(_ payload: MetricPayload) {

        // No reason to send anything if we don't have any signposts
        guard let signpostMetrics = payload.signpostMetrics, signpostMetrics.isEmpty == false else {
            return
        }

        if let data = try? JSONEncoder().encode(payload) {

            #if DEBUG
                // Remove this when we know stuff works
                if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                    let uuid = UUID().uuidString
                    let url: URL = .documentsDirectory.appendingPathComponent("\(uuid)_em.json")
                    try? data.write(to: url)
                }
            #endif

            sendMetric(payload: data)
        }
    }

    func handlePayload(_ payload: MetricKitDiagnosticPayload) {
        // check if the payload should be linked to the latest session
        var sessionId: EmbraceIdentifier?

        if let session = _lastSession.safeValue {
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

    func add(listener: any MetricKitMetricsPayloadListener) {
        _metricsListeners.withLock {
            $0.append(listener)
        }
    }

    func sendCrash(payload: Data, signal: Int, sessionId: EmbraceIdentifier?) {
        for listener in crashListeners {
            listener.didReceive(payload: payload, signal: signal, sessionId: sessionId)
        }
    }

    func sendHang(payload: Data, startTime: Date, endTime: Date) {
        for listener in hangListeners {
            listener.didReceive(payload: payload, startTime: startTime, endTime: endTime)
        }
    }

    func sendMetric(payload: Data) {
        for listener in metricsListeners {
            listener.didReceive(metric: payload)
        }
    }
}

#if canImport(MetricKit) && !os(macOS) && !os(tvOS)
    extension MetricKitHandler: MXMetricManagerSubscriber {
        func didReceive(_ payloads: [MXMetricPayload]) {
            for payload in payloads {

                #if DEBUG
                    // Remove this when we know stuff works
                    if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                        let uuid = UUID().uuidString
                        let url: URL = .documentsDirectory.appendingPathComponent("\(uuid)_mx.json")
                        try? payload.jsonRepresentation().write(to: url)
                    }
                #endif

                handlePayload(MetricPayload(payload: payload))
            }
        }

        @available(iOS 14.0, *)
        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            for payload in payloads {
                handlePayload(MetricKitDiagnosticPayload(payload: payload))
            }
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

    #if canImport(MetricKit) && !os(tvOS)
        @available(iOS 14.0, *)
        init(payload: MXDiagnosticPayload) {
            self.startTime = payload.timeStampBegin
            self.endTime = payload.timeStampEnd
            self.crashes =
                payload.crashDiagnostics?.map({
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
