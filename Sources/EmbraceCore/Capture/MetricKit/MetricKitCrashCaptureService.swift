//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

class MetricKitCrashCaptureService: CaptureService, MetricKitCrashPayloadListener {

    let options: MetricKitCrashCaptureService.Options

    init(options: MetricKitCrashCaptureService.Options) {
        self.options = options
    }

    override func onInstall() {
        options.payloadProvider?.add(listener: self)
    }

    func didReceive(payload: Data, signal: Int, sessionId: SessionIdentifier?) {
        guard state == .active,
            let stateProvider = options.stateProvider,
            stateProvider.isMetricKitEnabled,
            stateProvider.isMetricKitCrashCaptureEnabled,
            stateProvider.metricKitCrashSignals.contains(signal)
        else {
            return
        }

        guard let payloadString = String(data: payload, encoding: .utf8) else {
            return
        }

        // generate otel log
        let attributesBuilder = EmbraceLogAttributesBuilder(
            session: nil,
            crashReport: nil,
            storage: options.metadataFetcher,
            initialAttributes: [:]
        )

        let attributes =
            attributesBuilder
            .addLogType(.crash)
            .addApplicationProperties(sessionId: sessionId)
            .addApplicationState(SessionState.unknown.rawValue)
            .addSessionIdentifier(sessionId?.toString)
            .addCrashReportProperties(
                id: UUID().withoutHyphen, provider: LogSemantics.Crash.metrickitProvider, payload: payloadString
            )
            .build()

        otel?.log(
            "",
            severity: .fatal,
            type: .crash,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: .notIncluded
        )
    }
}
