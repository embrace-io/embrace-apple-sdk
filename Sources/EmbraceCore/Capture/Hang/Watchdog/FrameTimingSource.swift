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
    /// This approach is dynamic-rate–safe: using `targetTimestamp` rather than a fixed frame
    /// duration means ProMotion, Low Power Mode, and `preferredFrameRateRange` transitions never
    /// produce false deltas. `CADisplayLink` also pauses automatically in the background, so
    /// suspend gaps are excluded without any extra bookkeeping.
    final class FrameTimingSource {

        /// Called on each frame tick (after the first, which only arms the comparison) with the
        /// delay in seconds between the tick's actual timestamp and the previous tick's
        /// `targetTimestamp`. A positive value means the frame arrived later than promised.
        var onTick: ((TimeInterval) -> Void)?

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
            defer {
                previousTickExpectedTimestamp = currentTick.targetTimestamp
            }

            guard let expectedTimestamp = previousTickExpectedTimestamp else {
                // First tick: arm for the next frame, nothing to compare yet.
                return
            }

            let delay = currentTick.timestamp - expectedTimestamp
            onTick?(delay)
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
