//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import OpenTelemetryApi

@objc public class LowMemoryWarningCollector: NSObject, InstalledCollector {

    public let otel: EmbraceOpenTelemetry = EmbraceOTel()

    @ThreadSafe var started = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func install() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: NSNotification.Name("UIApplicationDidReceiveMemoryWarningNotification"), // hardcoded string so we dont have to use UIApplication
            object: nil
        )
    }

    public func shutdown() {
        NotificationCenter.default.removeObserver(self)
        started = false
    }

    public func start() {
        started = true
    }

    public func stop() {
        started = false
    }

    public func isAvailable() -> Bool {
        return true
    }

    @objc func didReceiveMemoryWarning(notification: Notification) {
        guard started else {
            return
        }

        let event = RecordingSpanEvent(name: "emb-device-low-memory", timestamp: Date())
        Embrace.client?.add(event: event)
    }
}
