//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    /// A single backtrace of the main thread captured *while the main thread was blocked*.
    struct MainThreadStackSample {

        /// Capture time in `CLOCK_MONOTONIC_RAW` nanoseconds — identical to `backtrace.timestamp`.
        ///
        /// Used to reconcile the sample against the CADisplayLink-confirmed hang window: the window
        /// is derived from the same clock (see `HangCaptureService.hangEnded`), so a sample is
        /// "in window" iff its `timestamp` falls inside it.
        let timestamp: UInt64

        /// Measured cost of the suspend + walk, in nanoseconds. Reported as `sample_overhead`.
        let overhead: UInt64

        /// The captured main-thread stack.
        let backtrace: EmbraceBacktrace
    }

    /// Supplies main-thread stacks captured *while the main thread was blocked*.
    ///
    /// This is the seam that decouples `HangCaptureService` from *how* the during-block stack is
    /// obtained. `FrameRateMonitor` (CADisplayLink) remains the sole authority on whether a hang is
    /// reported and its boundaries; a conforming sampler's only job is to have a during-block stack
    /// ready to hand back once the hang is confirmed.
    ///
    /// The current implementation is `StallTriggeredSampler`. Because the contract is just
    /// "give me buffered during-block samples in this time range", a later step can drop in an
    /// adapter over the shared profiling engine's sample store with **no change** to
    /// `HangCaptureService`.
    ///
    /// - Note: A sampler must be **free-running** — CADisplayLink only confirms a hang *after* the
    ///   main thread unblocks, so the stack has to have been captured already. It cannot be started
    ///   in response to the detector.
    protocol MainThreadStackSampler: AnyObject {

        /// Begins sampling. Called once the feature is enabled (same gate as the monitor).
        func start()

        /// Stops sampling and releases resources. Called on teardown / config disable.
        func stop()

        /// Pauses sampling without tearing down (e.g. app backgrounded).
        func pause()

        /// Resumes sampling after a `pause()` (e.g. app foregrounded).
        func resume()

        /// Buffered during-block samples whose capture `timestamp` falls within `range`
        /// (`CLOCK_MONOTONIC_RAW` ns), ordered oldest to newest.
        func samples(in range: ClosedRange<UInt64>) -> [MainThreadStackSample]
    }

#endif
