//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

/// Service that generates OpenTelemetry spans when the phone is running in low power mode.
@objc(EMBLowPowerModeCaptureService)
public class LowPowerModeCaptureService: CaptureService {
    public let provider: PowerModeProvider

    @ThreadSafe var wasLowPowerModeEnabled = false
    @ThreadSafe var currentSpan: EmbraceSpan?

    public init(provider: PowerModeProvider = DefaultPowerModeProvider()) {
        self.provider = provider
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        endSpan()
    }

    override public func onInstall() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangePowerMode),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    override public func onStart() {
        if provider.isLowPowerModeEnabled {
            startSpan(wasManuallyFetched: true)
        }

        wasLowPowerModeEnabled = provider.isLowPowerModeEnabled
    }

    override public func onStop() {
        endSpan()
    }

    @objc func didChangePowerMode(notification: Notification) {
        guard state == .active else {
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

        let reason = wasManuallyFetched ? SpanSemantics.LowPower.systemQuery : SpanSemantics.LowPower.systemNotification

        currentSpan = try? otel?.createSpan(
            name: SpanSemantics.LowPower.name,
            type: .lowPower,
            attributes: [
                SpanSemantics.LowPower.keyStartReason: reason
            ]
        )
    }

    func endSpan() {
        currentSpan?.end()
        currentSpan = nil
    }
}
