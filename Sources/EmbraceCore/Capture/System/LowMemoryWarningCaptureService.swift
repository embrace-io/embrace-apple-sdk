//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceSemantics
import OpenTelemetryApi

/// Service that generates OpenTelemetry span events when the application receives a low memory warning.
@objc(EMBLowMemoryWarningCaptureService)
public class LowMemoryWarningCaptureService: CaptureService {

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

        let event = RecordingSpanEvent(
            name: SpanEventSemantics.LowMemory.name,
            timestamp: Date(),
            attributes: [
                SpanEventSemantics.keyEmbraceType: .string(SpanType.lowMemory.rawValue)
            ]
        )

        if add(event: event) {
            onWarningCaptured?()
        }
    }
}
