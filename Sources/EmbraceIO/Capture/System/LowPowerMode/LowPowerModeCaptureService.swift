//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import OpenTelemetryApi

@objc public class LowPowerModeCaptureService: NSObject, InstalledCaptureService {

    public let provider: PowerModeProvider
    public let otel: EmbraceOpenTelemetry

    @ThreadSafe var started = false
    @ThreadSafe var wasLowPowerModeEnabled = false
    @ThreadSafe var currentSpan: Span?

    public init(provider: PowerModeProvider = DefaultPowerModeProvider()) {
        self.provider = provider
        self.otel = EmbraceOTel()
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
