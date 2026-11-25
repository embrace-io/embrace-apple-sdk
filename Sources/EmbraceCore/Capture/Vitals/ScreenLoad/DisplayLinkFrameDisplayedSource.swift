//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation
    import QuartzCore

    /// A ``FrameDisplayedSource`` that waits for the next Core Animation commit on the main run loop,
    /// then reports the next `CADisplayLink` callback's `timestamp`. That timestamp is on the
    /// `CACurrentMediaTime()` base, which is the system uptime base.
    ///
    /// `timestamp` (the vsync that started the frame carrying the commit) is used rather than
    /// `targetTimestamp` (about one frame later) to match Android, which reports the first frame's
    /// `FrameMetrics.VSYNC_TIMESTAMP`, the vsync its draw started on.
    ///
    /// The run-loop observer and display link exist only while a request is waiting, so an idle source
    /// costs nothing per frame. Requests are batched: every request waiting when a commit happens is
    /// answered by the same display link callback. A request made after a commit waits for the next
    /// one, even if a callback for the earlier commit is still due.
    ///
    /// Kept separate from the hang detector's `FrameRateMonitor`, which runs its display link
    /// continuously, so the two features stay independent. It doesn't build on `EMBDisplayLinkProxy`,
    /// which startup tracking already uses: that is a singleton with one callback slot, keeps its
    /// display link alive while paused, and doesn't pass the frame's timestamp.
    ///
    /// ## Threading
    /// Main thread only, and deliberately unsynchronized. Calls off the main thread are dropped and
    /// reported rather than asserted, since `dispatchPrecondition` would terminate the host app.
    final class DisplayLinkFrameDisplayedSource: FrameDisplayedSource, DisplayLinkTickTarget {

        /// The order of Core Animation's own commit observer on the main run loop. Observing after it
        /// means the commit has already happened.
        static let coreAnimationCommitOrder: CFIndex = 2_000_000

        private let proxy = WeakDisplayLinkProxy()

        // Requests waiting for the next commit.
        private var awaitingCommit: [FrameDisplayedHandler] = []

        // Requests whose commit happened, waiting for the next display link callback.
        private var awaitingFrame: [FrameDisplayedHandler] = []

        // Bumped by `stop()`, so a handler that stops the source cancels the rest of its batch.
        private var stopGeneration = 0

        private var observer: CFRunLoopObserver?
        private var displayLink: CADisplayLink?

        /// Whether the run-loop observer or display link currently exists.
        var isActive: Bool {
            observer != nil || displayLink != nil
        }

        init() {
            proxy.target = self
        }

        deinit {
            removeObserver()
            removeDisplayLink()
        }

        func requestNextFrame(_ handler: @escaping FrameDisplayedHandler) {
            guard isOnMainThread("A frame request") else { return }

            awaitingCommit.append(handler)
            addObserverIfNeeded()
        }

        func stop() {
            guard isOnMainThread("A stop") else { return }

            stopGeneration += 1
            awaitingCommit.removeAll()
            awaitingFrame.removeAll()
            removeObserver()
            removeDisplayLink()
        }

        // MARK: - Private

        /// Returns whether this is the main thread, logging that `operation` was dropped if not.
        private func isOnMainThread(_ operation: String) -> Bool {
            guard Thread.isMainThread else {
                Embrace.logger.error(
                    "Screen load: \(operation) arrived off the main thread and was dropped. "
                        + "The frame-displayed source must be used on the main thread.")
                return false
            }
            return true
        }

        private func addObserverIfNeeded() {
            guard observer == nil else { return }

            // The same activities Core Animation commits on.
            let observer = CFRunLoopObserverCreateWithHandler(
                kCFAllocatorDefault,
                CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue,
                true,
                Self.coreAnimationCommitOrder + 1
            ) { [weak self] _, _ in
                self?.commitObserved()
            }
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            self.observer = observer
        }

        private func removeObserver() {
            guard let observer else { return }

            CFRunLoopObserverInvalidate(observer)
            self.observer = nil
        }

        private func addDisplayLinkIfNeeded() {
            guard displayLink == nil else { return }

            let link = CADisplayLink(target: proxy, selector: #selector(WeakDisplayLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func removeDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        private func commitObserved() {
            // The next callback is the first frame after this commit for any earlier batch too, so
            // the batches merge.
            awaitingFrame.append(contentsOf: awaitingCommit)
            awaitingCommit.removeAll()
            removeObserver()

            if !awaitingFrame.isEmpty {
                addDisplayLinkIfNeeded()
            }
        }

        func displayLinkDidTick(_ link: CADisplayLink) {
            let timestamp = link.timestamp
            let handlers = awaitingFrame
            awaitingFrame.removeAll()
            removeDisplayLink()

            // State is settled first, so a handler that requests again waits for the next commit.
            let stopGenerationAtTick = stopGeneration
            for handler in handlers {
                guard stopGeneration == stopGenerationAtTick else { return }
                handler(timestamp)
            }
        }
    }

#endif  // !os(watchOS) && !os(macOS)
