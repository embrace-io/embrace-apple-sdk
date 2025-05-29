//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCommonInternal
#endif

class MetricKitHangCaptureService: CaptureService, MetricKitHangPayloadListener {

    let providerIdentifier = "metrickit"

    let options: MetricKitHangCaptureService.Options

    init(options: MetricKitHangCaptureService.Options) {
        self.options = options
    }

    override func onInstall() {
        options.payloadProvider?.add(listener: self)
    }

    func didReceive(payload: Data, startTime: Date, endTime: Date) {
        guard state == .active,
              let stateProvider = options.stateProvider,
              stateProvider.isMetricKitEnabled,
              stateProvider.isMetricKitHangCaptureEnabled else {
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

        let attributes = attributesBuilder
            .addLogType(.hang)
            .addApplicationState(SessionState.unknown.rawValue)
            .addHangReportProperties(
                id: UUID().withoutHyphen,
                provider: providerIdentifier,
                payload: payloadString,
                startTime: startTime,
                endTime: endTime
            )
            .build()

        otel?.log(
            "",
            severity: .warn,
            type: .hang,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: .notIncluded
        )
    }
}
