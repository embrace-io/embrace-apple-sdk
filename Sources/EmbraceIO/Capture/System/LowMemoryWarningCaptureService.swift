//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import OpenTelemetryApi

@objc public class LowMemoryWarningCaptureService: NSObject, InstalledCaptureService {

    public let otel: EmbraceOpenTelemetry = EmbraceOTel()
    public var onWarningCaptured: (() -> Void)?

    @ThreadSafe var started = false

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

        let event = RecordingSpanEvent(name: "emb-device-low-memory", timestamp: Date())
        Embrace.client?.add(event: event)

        onWarningCaptured?()
    }
}
