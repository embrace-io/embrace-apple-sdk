//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import OpenTelemetryApi

@objc public class LowMemoryWarningCaptureService: NSObject, InstalledCaptureService {
    private let otelProvider: EmbraceOTelHandlingProvider
    private var otel: EmbraceOpenTelemetry? {
        otelProvider.otelHandler
    }

    public var onWarningCaptured: (() -> Void)?

    @ThreadSafe var started = false

    public override init() {
        self.otelProvider = EmbraceOtelProvider()
    }

    internal init(otelProvider: EmbraceOTelHandlingProvider) {
        self.otelProvider = otelProvider
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    public func install(context: EmbraceCommon.CaptureServiceContext) {
        // hardcoded string so we dont have to use UIApplication
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: NSNotification.Name("UIApplicationDidReceiveMemoryWarningNotification"),
            object: nil
        )
    }

    public func uninstall() {
        NotificationCenter.default.removeObserver(self)
        started = false
    }

    public func start() {
        started = true
    }

    public func stop() {
        started = false
    }

    @objc func didReceiveMemoryWarning(notification: Notification) {
        guard started else {
            return
        }

        guard let otel = otel else {
            ConsoleLog.error("Missing Embrace Otel when trying to start a span on LowMemoryWarningCaptureService")
            return
        }

        let event = RecordingSpanEvent(name: "emb-device-low-memory", timestamp: Date())
        otel.add(event: event)

        onWarningCaptured?()
    }
}
