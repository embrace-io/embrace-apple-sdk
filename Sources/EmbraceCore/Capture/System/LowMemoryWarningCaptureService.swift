//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommon
import EmbraceOTel
import OpenTelemetryApi

@objc public class LowMemoryWarningCaptureService: CaptureService {

    public var onWarningCaptured: (() -> Void)?

    @ThreadSafe var started = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func onInstall() {
        // hardcoded string so we dont have to use UIApplication
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: NSNotification.Name("UIApplicationDidReceiveMemoryWarningNotification"),
            object: nil
        )
    }

    @objc func didReceiveMemoryWarning(notification: Notification) {
        guard state == .active else {
            return
        }

        let event = RecordingSpanEvent(name: "emb-device-low-memory", timestamp: Date())

        if add(event: event) {
            onWarningCaptured?()
        }
    }
}
