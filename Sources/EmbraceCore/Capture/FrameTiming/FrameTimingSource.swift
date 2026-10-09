//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import QuartzCore

    /// Reports, on each `CADisplayLink` tick, how late it arrived relative to the previous tick's
    /// `targetTimestamp`.
    ///
    /// Using `targetTimestamp` rather than a fixed frame duration keeps the delay correct at
    /// hang scale across ProMotion, Low Power Mode, and `preferredFrameRateRange` transitions.
    /// When the refresh rate steps down, the tick can land up to one frame interval late without a
    /// missed frame. `Tick` carries both frame intervals so consumers can discount this.
    ///
    /// The delay only reflects when the main run loop serviced the display link, so it catches a
    /// blocked main thread but not frames missed in the commit, render server, or GPU while main
    /// was free.
    ///
    /// `CADisplayLink` pauses automatically in the background, so suspend gaps are excluded
    /// without any extra bookkeeping.
    final class FrameTimingSource {

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

        /// Called on each frame tick after the first.
        var onTick: ((Tick) -> Void)?

        /// Creates a new `FrameTimingSource` and immediately begins observing frame timing.
        ///
        /// Must be called on the main thread.
        ///
        /// - Parameters:
        ///   - notificationCenter: Observed for will-enter-foreground, which re-arms the comparison.
        ///   - attachesDisplayLink: Whether to drive ticks from a `CADisplayLink`. Tests pass `false` and
        ///     deliver ticks through `handleTick`, so no real frame can land while they spin the run loop.
        init(notificationCenter: NotificationCenter = .default, attachesDisplayLink: Bool = true) {
            self.notificationCenter = notificationCenter
            self.proxy = DisplayLinkProxy()

            if attachesDisplayLink {
                let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
                link.add(to: .main, forMode: .common)
                self.displayLink = link
            }

            proxy.source = self

            notificationCenter.addObserver(
                self,
                selector: #selector(resetOnForeground),
                name: FrameTimingSource.willEnterForegroundNotification,
                object: nil
            )
        }

        deinit {
            notificationCenter.removeObserver(self)
            displayLink?.invalidate()
        }

        // MARK: - Private

        private let notificationCenter: NotificationCenter
        private let proxy: DisplayLinkProxy
        private var displayLink: CADisplayLink?

        /// The previous frame's `targetTimestamp` — the system's promise of when
        /// the current frame would fire.
        private var previousTickExpectedTimestamp: CFTimeInterval?

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

        /// Must be called on the main thread.
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
