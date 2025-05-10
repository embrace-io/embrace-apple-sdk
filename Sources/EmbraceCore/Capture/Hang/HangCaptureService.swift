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
        super.init()
        self.watchdog.hangObserver = self
    }

    private var watchdog: HangWatchdog
    private var span: OpenTelemetryApi.Span? = nil
}

extension HangCaptureService: HangObserver {
    
    public func hangStarted(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang started, for \(nanosecondsToMilliseconds(duration)) ms")
        span = buildSpan(name: "Hang", type: .performance, attributes: [:])?.startSpan()
    }
    
    public func hangUpdated(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang for \(nanosecondsToMilliseconds(duration)) ms")
        span?.addEvent(name: "hang.ping")
    }
    
    public func hangEnded(at time: UInt64, duration: UInt64) {
        logger?.debug("[AC:Watchdog] Hang ended at \(nanosecondsToMilliseconds(duration)) ms")
        span?.end()
        span = nil
    }
}

private func nanosecondsToSeconds(_ nanos: UInt64) -> Double {
    Double(nanos) / Double(NSEC_PER_SEC)
}

private func nanosecondsToMilliseconds(_ nanos: UInt64) -> UInt64 {
    nanos / NSEC_PER_MSEC
}
