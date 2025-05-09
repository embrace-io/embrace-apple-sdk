//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import UIKit
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceSemantics
#endif
import OpenTelemetryApi

/// Service that generates OpenTelemetry span events for hangs.
@objc(EMBHangCaptureService)
public final class HangCaptureService: CaptureService {

    public init(watchdog: HangWatchdog = HangWatchdog()) {
        self.watchdog = watchdog
    }

    private var watchdog: HangWatchdog
}
