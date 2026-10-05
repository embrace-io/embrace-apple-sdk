//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Service that generates OpenTelemetry spans when the phone is running in low power mode.
public final class LowPowerModeCaptureService: CaptureService {
    /// Provider used to read the device's Low Power Mode state.
    public let provider: PowerModeProvider

    private let wasLowPowerModeEnabled = EmbraceAtomic(false)
    internal let _currentSpan = EmbraceMutex<EmbraceSpan?>(nil)
    internal var currentSpan: EmbraceSpan? {
        _currentSpan.withLock { $0 }
    }

    /// Creates a new `LowPowerModeCaptureService` with the given provider.
    /// - Parameter provider: Provider used to read the device's Low Power Mode state.
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

        // create the span before taking the lock, since creating it calls the span processors' `onStart` inline.
        // if another span was stored while this one was starting, end it after releasing the lock so it isn't left open.
        guard
            let span = createSpan(
                name: SpanSemantics.LowPower.name,
                type: .lowPower,
                attributes: [SpanSemantics.LowPower.keyStartReason: reason]
            )
        else {
            Embrace.logger.warning("Error trying to create low power mode span!")
            return
        }

        let previous = _currentSpan.withLock {
            let previous = $0
            $0 = span
            return previous
        }
        previous?.end()
    }

    func endSpan() {
        _currentSpan.takeValue()?.end()
    }
}
