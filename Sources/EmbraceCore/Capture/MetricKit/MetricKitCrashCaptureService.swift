//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommonInternal

class MetricKitCrashCaptureService: CaptureService, MetricKitCrashPayloadListener {

    let providerIdentifier = "metrickit"

    let options: MetricKitCrashCaptureService.Options

    init(options: MetricKitCrashCaptureService.Options) {
        self.options = options
    }

    convenience override init() {
         self.init(options: MetricKitCrashCaptureService.Options())
    }

    override func onInstall() {
        options.provider?.add(listener: self)
    }

    func didReceive(payload: Data, signal: Int, sessionId: SessionIdentifier?) {
        guard state == .active else {
            return
        }

        guard options.signals.contains(signal) else {
            return
        }

        guard let payloadString = String(data: payload, encoding: .utf8) else {
            return
        }

        // generate otel log
        let attributesBuilder = EmbraceLogAttributesBuilder(
            session: nil,
            crashReport: nil,
            storage: Embrace.client?.storage,
            initialAttributes: [:]
        )

        let attributes = attributesBuilder
            .addLogType(.crash)
            .addApplicationProperties(sessionId: sessionId)
            .addApplicationState(SessionState.unknown.rawValue)
            .addSessionIdentifier(sessionId?.toString)
            .addCrashReportProperties(id: UUID().withoutHyphen, provider: providerIdentifier, payload: payloadString)
            .build()

        otel?.log(
            "",
            severity: .fatal,
            type: .crash,
            timestamp: Date(),
            attributes: attributes,
            stackTraceBehavior: .default
        )
    }
}
