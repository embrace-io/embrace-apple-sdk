//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommon
import EmbraceOTel

@objc public class LowPowerModeCaptureService: CaptureService {
    public let provider: PowerModeProvider

    @ThreadSafe var wasLowPowerModeEnabled = false
    @ThreadSafe var currentSpan: Span?

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

        guard let builder = buildSpan(
            name: "emb-device-low-power",
            type: .lowPower,
            attributes: ["start_reason": wasManuallyFetched ? "system_query" : "system_notification"]
        ) else {
            ConsoleLog.warning("Error trying to create low power mode span!")
            return
        }

        currentSpan = builder.startSpan()
    }

    func endSpan() {
        currentSpan?.end()
        currentSpan = nil
    }
}
