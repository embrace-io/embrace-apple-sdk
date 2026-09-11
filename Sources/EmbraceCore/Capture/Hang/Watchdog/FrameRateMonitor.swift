//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

    /// Detects main-thread hangs from `FrameTimingSource`'s frame-delay reports.
    ///
    /// On each frame delay report, a delay exceeding `threshold` is reported as a completed hang
    /// to the `hangObserver`. Because `FrameTimingSource` only reports a delay once the hang is
    /// already over, the hang is reported retroactively.
    final class FrameRateMonitor {

        /// Apple's own definition of a hang (≈ 250 ms).
        /// See: https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app
        static let defaultAppleHangThreshold: TimeInterval = 0.249

        /// Minimum frame delay (seconds) that is reported as a hang.
        let threshold: TimeInterval

        /// Receives hang lifecycle callbacks.
        weak var hangObserver: HangObserver?

        /// Optional logger for diagnostic output.
        internal var logger: InternalLogger?

        /// Creates a new `FrameRateMonitor` and immediately begins observing frame timing.
        ///
        /// Must be called on the main thread.
        init(threshold: TimeInterval = FrameRateMonitor.defaultAppleHangThreshold) {
            self.threshold = threshold
            self.timingSource = FrameTimingSource()

            timingSource.onTick = { [weak self] delay in
                self?.handle(delay: delay)
            }
        }

        // MARK: - Private

        private let timingSource: FrameTimingSource

        private func handle(delay: TimeInterval) {
            guard delay > threshold else { return }

            // The main thread was blocked beyond `threshold`.
            // The hang is already over — report it retroactively.
            let now = Date()
            let currentDateTimeInterval = now.timeIntervalSince1970
            let previousTickTimeInterval = currentDateTimeInterval - delay
            let previousTickDate = Date(timeIntervalSince1970: previousTickTimeInterval)

            logger?.debug("[FrameRateMonitor] Hang detected: \((Int(delay * 1000))) ms")

            hangObserver?.hangStarted(at: previousTickDate, duration: delay)
            hangObserver?.hangEnded(at: now, duration: delay)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
