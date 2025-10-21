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

    private let wasLowPowerModeEnabled = EmbraceAtomic(false)
    internal let currentSpan = EmbraceMutex<Span?>(nil)

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

        wasLowPowerModeEnabled.store(provider.isLowPowerModeEnabled)
    }

    override public func onStop() {
        endSpan()
    }

    @objc func didChangePowerMode(notification: Notification) {
        guard isActive else {
            return
        }

        let prevLowPowerMode = wasLowPowerModeEnabled.exchange(provider.isLowPowerModeEnabled)
        if provider.isLowPowerModeEnabled && !prevLowPowerMode {
            startSpan()
        } else if !provider.isLowPowerModeEnabled && prevLowPowerMode {
            endSpan()
        }
    }

    func startSpan(wasManuallyFetched: Bool = false) {
        endSpan()

        let reason = wasManuallyFetched ? SpanSemantics.LowPower.systemQuery : SpanSemantics.LowPower.systemNotification

        guard
            let builder = buildSpan(
                name: SpanSemantics.LowPower.name,
                type: .lowPower,
                attributes: [SpanSemantics.LowPower.keyStartReason: reason]
            )
        else {
            Embrace.logger.warning("Error trying to create low power mode span!")
            return
        }

        currentSpan.withLock {
            $0 = builder.startSpan()
        }
    }

    func endSpan() {
        currentSpan.withLock {
            $0?.end()
            $0 = nil
        }
    }
}
