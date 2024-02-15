//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import OpenTelemetryApi

@objc public class LowPowerModeCaptureService: NSObject, InstalledCaptureService {
    public let provider: PowerModeProvider
    private let otelProvider: EmbraceOTelHandlingProvider
    private var otel: EmbraceOpenTelemetry? {
        otelProvider.otelHandler
    }

    @ThreadSafe var started = false
    @ThreadSafe var wasLowPowerModeEnabled = false
    @ThreadSafe var currentSpan: Span?

    public init(provider: PowerModeProvider = DefaultPowerModeProvider()) {
        self.provider = provider
        self.otelProvider = EmbraceOtelProvider()
    }

    internal init(provider: PowerModeProvider = DefaultPowerModeProvider(),
                  otelProvider: EmbraceOTelHandlingProvider) {
        self.provider = provider
        self.otelProvider = otelProvider
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func install(context: EmbraceCommon.CaptureServiceContext) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangePowerMode),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    public func uninstall() {
        NotificationCenter.default.removeObserver(self)
        started = false

        endSpan()
    }

    public func start() {
        started = true

        if provider.isLowPowerModeEnabled {
            startSpan(wasManuallyFetched: true)
        }

        wasLowPowerModeEnabled = provider.isLowPowerModeEnabled
    }

    public func stop() {
        started = false

        endSpan()
    }

    @objc func didChangePowerMode(notification: Notification) {
        guard started else {
            return
        }

        if provider.isLowPowerModeEnabled && !wasLowPowerModeEnabled {
            startSpan()
        } else if !provider.isLowPowerModeEnabled && wasLowPowerModeEnabled {
            endSpan()
        }

        wasLowPowerModeEnabled = provider.isLowPowerModeEnabled
    }

    func startSpan(wasManuallyFetched: Bool = false) {
        guard let otel = self.otel else {
            ConsoleLog.error("Missing Embrace Otel when trying to start a span on LowPowerModeCaptureService")
            return
        }
        endSpan()

        let builder = otel.buildSpan(
            name: "emb-device-low-power",
            type: .performance,
            attributes: ["start_reason": wasManuallyFetched ? "system_query" : "system_notification"]
        )

        currentSpan = builder.startSpan()
    }

    func endSpan() {
        currentSpan?.end()
        currentSpan = nil
    }
}
