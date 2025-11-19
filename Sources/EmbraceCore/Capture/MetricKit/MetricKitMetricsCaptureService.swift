//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

@available(iOS 13.0, macOS 12.0, *)
class MetricKitMetricsCaptureService: CaptureService, MetricKitMetricsPayloadListener {

    let options: MetricKitCaptureServiceOptions

    init(options: MetricKitCaptureServiceOptions) {
        self.options = options
        if let stateProvider = options.stateProvider {
            EmbraceMetricKitSpan.bootstrap(enabled: stateProvider.isMetricKitEnabled && stateProvider.isMetricKitInternalMetricsCaptureEnabled)
        }
    }

    override func onInstall() {
        options.payloadProvider?.add(listener: self)
    }

    override func onConfigUpdated(_ config: any EmbraceConfigurable) {
        EmbraceMetricKitSpan.bootstrap(enabled: config.isMetricKitEnabled && config.isMetricKitInternalMetricsCaptureEnabled)
    }

    func didReceive(metric payload: Data) {
        guard isActive,
            let stateProvider = options.stateProvider,
            stateProvider.isMetricKitEnabled,
            stateProvider.isMetricKitInternalMetricsCaptureEnabled
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
            .addLogType(.metricKitMetrics)
            .addApplicationState(SessionState.unknown.rawValue)
            .addMetricKitMetricsProperties(
                id: UUID().withoutHyphen,
                provider: LogSemantics.MetricKitMetrics.metrickitProvider,
                payload: payloadString
            )
            .build()

        otel?.log(
            "MetricKit Internal Metrics",
            severity: .info,
            type: .metricKitMetrics,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: .notIncluded
        )
    }
}
