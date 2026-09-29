//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import QuartzCore

    /// Observes frame delivery via `CADisplayLink` and reports, on each frame, how far the actual
    /// delivery time drifted from the system's own committed schedule.
    ///
    /// On each tick, `FrameTimingSource` compares the current delivery time against the previous
    /// frame's `targetTimestamp` — the system's promise of when that frame would fire — and reports
    /// the difference via `onTick`.
    ///
    /// Using `targetTimestamp` rather than a fixed frame duration keeps the delay correct at
    /// hang scale across ProMotion, Low Power Mode, and `preferredFrameRateRange` transitions.
    /// It is not exact at sub-frame scale: when the refresh rate steps down, the next tick lands
    /// up to one frame interval after the previous `targetTimestamp`, which shows up as a small
    /// delay. Each `Tick` carries the frame interval before and after, so consumers that account
    /// for sub-frame lateness (`FrameDropClassifier`) can discount it.
    ///
    /// The delay only reflects when the main run loop serviced the display link, so it catches a
    /// blocked main thread but not frames missed in the commit, render server, or GPU while main
    /// was free.
    ///
    /// `CADisplayLink` pauses automatically in the background, so suspend gaps are excluded
    /// without any extra bookkeeping.
    final class FrameTimingSource {

        /// One frame tick's timing.
        struct Tick {
            /// Seconds between the tick's actual timestamp and the previous tick's
            /// `targetTimestamp`. A positive value means the frame arrived later than promised.
            let delay: TimeInterval

            /// This tick's frame interval (`targetTimestamp - timestamp`).
            let frameInterval: TimeInterval

            /// The previous tick's frame interval. Differs from `frameInterval` when the refresh
            /// rate changed between the two ticks.
            let previousFrameInterval: TimeInterval
        }

        /// Called on each frame tick, after the first, which only arms the comparison.
        var onTick: ((Tick) -> Void)?

        /// Creates a new `FrameTimingSource` and immediately begins observing frame timing.
        ///
        /// Must be called on the main thread.
        init() {
            self.proxy = DisplayLinkProxy()

            let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link

            proxy.source = self

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(resetOnForeground),
                name: FrameTimingSource.willEnterForegroundNotification,
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

        /// The previous frame's `targetTimestamp` — the system's promise of when
        /// the current frame would fire.
        private var previousTickExpectedTimestamp: CFTimeInterval?

        /// The previous frame's `targetTimestamp - timestamp`.
        private var previousFrameInterval: CFTimeInterval = 0

        /// Raw notification name to avoid a direct UIKit dependency.
        private static let willEnterForegroundNotification =
            Notification.Name("UIApplicationWillEnterForegroundNotification")

        /// Resets state on foreground so the first tick after a background/foreground
        /// transition does not report a spurious delta.
        @objc private func resetOnForeground() {
            previousTickExpectedTimestamp = nil
        }
    }

    // MARK: - Frame tick

    extension FrameTimingSource {

        fileprivate func tick(_ currentTick: CADisplayLink) {
            handleTick(timestamp: currentTick.timestamp, targetTimestamp: currentTick.targetTimestamp)
        }

        /// Compares a tick's `timestamp` against the previous tick's `targetTimestamp`. Must be called
        /// on the main thread.
        func handleTick(timestamp: CFTimeInterval, targetTimestamp: CFTimeInterval) {
            let frameInterval = targetTimestamp - timestamp
            defer {
                previousTickExpectedTimestamp = targetTimestamp
                previousFrameInterval = frameInterval
            }

            guard let expectedTimestamp = previousTickExpectedTimestamp else {
                // First tick: arm for the next frame, nothing to compare yet.
                return
            }

            onTick?(
                Tick(
                    delay: timestamp - expectedTimestamp,
                    frameInterval: frameInterval,
                    previousFrameInterval: previousFrameInterval
                ))
        }
    }

    // MARK: - Weak proxy

    extension FrameTimingSource {

        /// Holds a weak reference to `FrameTimingSource` to break the retain cycle
        /// that `CADisplayLink` would otherwise form with its target.
        private final class DisplayLinkProxy: NSObject {
            weak var source: FrameTimingSource?

            @objc func tick(_ link: CADisplayLink) {
                source?.tick(link)
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
