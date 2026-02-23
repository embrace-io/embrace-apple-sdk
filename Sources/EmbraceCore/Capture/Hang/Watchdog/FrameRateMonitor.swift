//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)

import Foundation
import QuartzCore

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// Monitors frame rendering timing to detect main-thread hangs.
///
/// `FrameRateMonitor` uses `CADisplayLink` to observe frame delivery on the
/// main thread. On each frame, it compares the actual delivery time against
/// the system's own committed schedule (`targetTimestamp` from the previous
/// tick). A delay exceeding `threshold` is reported as a completed hang to
/// the `hangObserver`.
///
/// This approach is dynamic-rate–safe: using `targetTimestamp` rather than a
/// fixed frame duration means ProMotion, Low Power Mode, and
/// `preferredFrameRateRange` transitions never produce false positives.
/// `CADisplayLink` also pauses automatically in the background, so suspend
/// gaps are excluded without any extra bookkeeping.
public final class FrameRateMonitor {

    /// Apple's own definition of a hang (≈ 250 ms).
    public static let defaultAppleHangThreshold: TimeInterval = 0.249

    /// Minimum frame delay (seconds) that is reported as a hang.
    public let threshold: TimeInterval

    /// Receives hang lifecycle callbacks.
    public weak var hangObserver: HangObserver?

    /// Optional logger for diagnostic output.
    internal var logger: InternalLogger?

    /// Creates a new `FrameRateMonitor` and immediately begins observing frame timing.
    ///
    /// Must be called on the main thread.
    public init(threshold: TimeInterval = FrameRateMonitor.defaultAppleHangThreshold) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.threshold = threshold
        self.proxy = DisplayLinkProxy()

        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.displayLink = link

        proxy.monitor = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetOnForeground),
            name: FrameRateMonitor.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        displayLink?.invalidate()
    }

    // MARK: - Private

    private let proxy: DisplayLinkProxy
    private var displayLink: CADisplayLink?

    /// The previous frame's `targetTimestamp` (the system's promise for when
    /// the current frame would fire) and the `EmbraceClock` snapshot taken
    /// when that frame actually fired.
    private var previousTick: (targetTimestamp: CFTimeInterval, clock: EmbraceClock)?

    /// Raw notification name to avoid a direct UIKit dependency.
    private static let willEnterForegroundNotification =
        Notification.Name("UIApplicationWillEnterForegroundNotification")

    /// Resets state on foreground so the first tick after a background/foreground
    /// transition is not misreported as a hang.
    @objc private func resetOnForeground() {
        previousTick = nil
    }
}

// MARK: - Frame tick

extension FrameRateMonitor {

    fileprivate func tick(_ link: CADisplayLink) {
        let now = EmbraceClock.current

        defer {
            previousTick = (link.targetTimestamp, now)
        }

        guard let previousTick else {
            // First tick: arm for the next frame, nothing to compare yet.
            return
        }

        let delay = link.timestamp - previousTick.targetTimestamp
        guard delay > threshold else {
            return
        }

        // The main thread was blocked beyond `threshold`.
        // The hang is already over — report it retroactively.
        let duration = now - previousTick.clock

        logger?.debug("[FrameRateMonitor] Hang detected: \(duration.uptime.millisecondsValue) ms")

        hangObserver?.hangStarted(at: previousTick.clock, duration: duration)
        hangObserver?.hangEnded(at: now, duration: duration)
    }
}

// MARK: - Weak proxy

extension FrameRateMonitor {

    /// Holds a weak reference to `FrameRateMonitor` to break the retain cycle
    /// that `CADisplayLink` would otherwise form with its target.
    private final class DisplayLinkProxy: NSObject {
        weak var monitor: FrameRateMonitor?

        @objc func tick(_ link: CADisplayLink) {
            monitor?.tick(link)
        }
    }
}

#endif // !os(watchOS)
