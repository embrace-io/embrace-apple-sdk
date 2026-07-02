//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

class MetricKitHangCaptureService: CaptureService, MetricKitHangPayloadListener {

    let options: MetricKitCaptureServiceOptions

    init(options: MetricKitCaptureServiceOptions) {
        self.options = options
    }

    override func onInstall() {
        options.payloadProvider?.add(listener: self)
    }

    func didReceive(payload: Data, startTime: Date, endTime: Date) {
        guard isActive,
            let stateProvider = options.stateProvider,
            stateProvider.isMetricKitEnabled,
            stateProvider.isMetricKitHangCaptureEnabled
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
            .addLogType(.hang)
            .addApplicationState(SessionState.unknown)
            .addHangReportProperties(
                id: UUID().withoutHyphen,
                provider: LogSemantics.Hang.metrickitProvider,
                payload: payloadString,
                startTime: startTime,
                endTime: endTime
            )
            .build()

        try? otel?.internalLog(
            "",
            severity: .warn,
            type: .hang,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: .notIncluded
        )
    }
}
