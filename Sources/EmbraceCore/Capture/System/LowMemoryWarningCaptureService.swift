//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Service that generates OpenTelemetry span events when the application receives a low memory warning.
@objc(EMBLowMemoryWarningCaptureService)
public class LowMemoryWarningCaptureService: CaptureService {

    @ThreadSafe var started = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func onInstall() {
        // hardcoded string so we don't have to use UIApplication
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

        try? otel?.addInternalSessionEvent(
            name: SpanEventSemantics.LowMemory.name,
            type: .lowMemory
        )
    }
}
