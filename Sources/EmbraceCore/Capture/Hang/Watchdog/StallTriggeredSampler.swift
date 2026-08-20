//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceConfiguration
        import EmbraceObjCUtilsInternal
    #endif

    /// Lock-free state shared between the sampler and its background poll loop. Both hold the **same**
    /// instance (it's a reference type), so the main-thread beacon's writes, the public lifecycle
    /// calls, and the loop all observe one source of truth. Bundling it into a single object is what
    /// lets the loop share exactly this state and nothing else — the worker is handed this, never the
    /// sampler — so there's no way to accidentally wire the loop to atomics nobody writes to.
    private final class SharedPollState {
        /// `CLOCK_MONOTONIC_RAW` ns when the current busy epoch began; `0` when the run loop is idle.
        /// Written by the main-thread beacon, read by the background poller.
        let busySince = EmbraceAtomic<UInt64>(0)
        let paused = EmbraceAtomic<Bool>(false)
        let running = EmbraceAtomic<Bool>(false)
        let buffer = EmbraceMutex<[MainThreadStackSample]>([])
    }

    /// Immutable poll-loop configuration. All value types, safe to copy into the worker.
    private struct PollConfig {
        let mainThread: pthread_t
        let triggerNanos: UInt64
        let pollNanos: UInt64
        let bufferCap: Int
    }

    /// Detects that the main thread *looks* stalled and captures a single during-block backtrace of
    /// it from a background thread. It does **not** decide whether a hang is reported —
    /// `FrameRateMonitor` (CADisplayLink) remains the authority. This only supplies the stack;
    /// stalls that CADisplayLink never confirms simply produce a buffered sample nobody queries.
    ///
    /// Detection is a lock-free liveness beacon plus a polling background thread:
    ///
    /// - A `CFRunLoopObserver` on the main run loop records, in the atomic `busySince`, the time the
    ///   current busy epoch began (`.afterWaiting`) and clears it when the loop goes idle
    ///   (`.beforeWaiting`). The handler runs on the main thread, so it does the absolute minimum —
    ///   one atomic store, no lock — to avoid burdening the thread we're trying to measure.
    /// - The background thread polls `busySince`. If the main thread has been continuously busy past
    ///   `triggerThreshold`, it takes **one** suspended snapshot of main and buffers it. The
    ///   `busySince` timestamp doubles as the epoch id: while main is blocked the run loop can't fire
    ///   the observer again, so the value is stable and we sample the episode exactly once.
    ///
    /// The trigger sits below the reported-hang threshold so the snapshot lands *inside* the hang
    /// window that CADisplayLink later confirms.
    final class StallTriggeredSampler: MainThreadStackSampler {

        private let shared = SharedPollState()
        private let config: PollConfig
        private weak var logger: InternalLogger?

        /// Lifecycle-owned resources. Guarded by a mutex so `start()`/`stop()` are mutually exclusive
        /// and these fields are never touched unlocked — the poll thread and the beacon never read
        /// them, so this lock is only ever contended by concurrent `start`/`stop`/`deinit` callers.
        private struct LifecycleState {
            var observer: CFRunLoopObserver?
            var thread: Thread?
            var tokens: [NSObjectProtocol] = []
        }
        private let lifecycle = EmbraceMutex(LifecycleState())

        /// - Parameters:
        ///   - mainThread: the `pthread_t` of the thread to sample. Defaults to the main thread,
        ///     resolved via `EmbraceGetMainThread()` (captured at load), so callers built off the main
        ///     thread — e.g. during a config-update rebuild — still target main correctly.
        ///   - triggerThreshold: how long main must be continuously busy before we snapshot it.
        ///     Clamped into `HangLimits.min/maxSampleTriggerThreshold`.
        ///   - pollInterval: how often the background thread checks liveness. Clamped into
        ///     `HangLimits.min/maxSamplePollInterval`.
        ///   - bufferCap: max buffered samples (small ring; one per stall episode).
        init(
            mainThread: pthread_t = EmbraceGetMainThread(),
            triggerThreshold: TimeInterval,
            pollInterval: TimeInterval = HangLimits.defaultSamplePollInterval,
            bufferCap: Int = 8,
            logger: InternalLogger?
        ) {
            self.config = PollConfig(
                mainThread: mainThread,
                triggerNanos: Self.clampedNanos(
                    triggerThreshold,
                    fallback: HangLimits.defaultSampleTriggerThreshold,
                    min: HangLimits.minSampleTriggerThreshold,
                    max: HangLimits.maxSampleTriggerThreshold
                ),
                pollNanos: Self.clampedNanos(
                    pollInterval,
                    fallback: HangLimits.defaultSamplePollInterval,
                    min: HangLimits.minSamplePollInterval,
                    max: HangLimits.maxSamplePollInterval
                ),
                // a cap < 1 would defeat buffering: 0 clears the ring every append, negative traps the trim.
                bufferCap: Swift.max(1, bufferCap)
            )
            self.logger = logger
        }

        deinit { stop() }

        /// Effective trigger after clamping, in seconds. Exposed for tests.
        var effectiveTriggerThreshold: TimeInterval { TimeInterval(config.triggerNanos) / 1_000_000_000 }

        /// Effective poll cadence after clamping, in seconds. Exposed for tests.
        var effectivePollInterval: TimeInterval { TimeInterval(config.pollNanos) / 1_000_000_000 }

        /// Values reaching `HangLimits` are already clamped; this is the defense-in-depth for direct
        /// callers. A non-finite value falls back to `fallback`; otherwise it is clamped into
        /// `[minimum, maximum]` (whose upper bound keeps the ns conversion from overflowing).
        private static func clampedNanos(
            _ value: TimeInterval,
            fallback: TimeInterval,
            min minimum: TimeInterval,
            max maximum: TimeInterval
        ) -> UInt64 {
            let base = value.isFinite ? value : fallback
            return UInt64(Swift.min(Swift.max(base, minimum), maximum) * 1_000_000_000)
        }

        // MARK: - MainThreadStackSampler

        func start() {
            lifecycle.withLock { state in
                guard !shared.running.load(order: .acquire) else { return }
                shared.running.store(true, order: .release)

                logger?.debug(
                    "[Hang] during-block sampler started (trigger \(Int(effectiveTriggerThreshold * 1000)) ms, "
                        + "poll \(Int(effectivePollInterval * 1000)) ms).")

                if let observer = makeObserver() {
                    state.observer = observer
                    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
                }
                state.tokens = makeLifecycleTokens()

                // The worker is handed the shared state and config but never `self`, so the poll thread
                // never retains the sampler; that keeps `deinit { stop() }` a real backstop.
                let worker = PollWorker(shared: shared, config: config)
                let thread = Thread { worker.run() }
                thread.name = "io.embrace.hang.sampler"
                thread.qualityOfService = .userInitiated
                state.thread = thread
                thread.start()
            }
        }

        func stop() {
            lifecycle.withLock { state in
                guard shared.running.load(order: .acquire) else { return }
                shared.running.store(false, order: .release)

                if let observer = state.observer {
                    CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
                }
                state.observer = nil

                let nc = NotificationCenter.default
                state.tokens.forEach { nc.removeObserver($0) }
                state.tokens = []

                state.thread = nil
                shared.busySince.store(0, order: .release)
            }
        }

        func pause() {
            shared.paused.store(true, order: .release)
            shared.busySince.store(0, order: .release)  // forget the current epoch across background
        }

        func resume() {
            shared.busySince.store(0, order: .release)  // fresh start; the beacon repopulates it
            shared.paused.store(false, order: .release)
        }

        func samples(in range: ClosedRange<UInt64>) -> [MainThreadStackSample] {
            shared.buffer.withLock { $0.filter { range.contains($0.timestamp) } }
        }

        // MARK: - Main-thread liveness beacon

        private func makeObserver() -> CFRunLoopObserver? {
            let activities = CFRunLoopActivity([.afterWaiting, .beforeWaiting]).rawValue
            return CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, activities, true, 0) {
                [weak self] _, activity in
                guard let self else { return }
                if activity == .beforeWaiting {
                    self.shared.busySince.store(0, order: .release)  // going idle → not a hang
                } else {
                    // .afterWaiting → a busy epoch begins. One atomic store, nothing else.
                    self.shared.busySince.store(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW), order: .release)
                }
            }
        }

        // MARK: - App lifecycle (raw names to avoid a UIKit dependency)

        private func makeLifecycleTokens() -> [NSObjectProtocol] {
            let nc = NotificationCenter.default
            return [
                nc.addObserver(
                    forName: Notification.Name("UIApplicationDidEnterBackgroundNotification"),
                    object: nil, queue: nil
                ) { [weak self] _ in self?.pause() },
                nc.addObserver(
                    forName: Notification.Name("UIApplicationWillEnterForegroundNotification"),
                    object: nil, queue: nil
                ) { [weak self] _ in self?.resume() }
            ]
        }
    }

    /// The background poll loop. Holds only the shared lock-free state and the immutable config,
    /// never the sampler, so the sampler's lifetime is not pinned to the loop's — the thread closure
    /// retains this worker instead. The shared state stays alive as long as the loop runs.
    private final class PollWorker {
        private let shared: SharedPollState
        private let config: PollConfig

        init(shared: SharedPollState, config: PollConfig) {
            self.shared = shared
            self.config = config
        }

        func run() {
            // The `busySince` value we last captured for. Loop-local: no synchronization needed.
            var lastSampledEpoch: UInt64 = 0

            while shared.running.load(order: .acquire) {
                Self.sleep(nanos: config.pollNanos)

                guard !shared.paused.load(order: .acquire) else { continue }

                let since = shared.busySince.load(order: .acquire)
                guard since != 0, since != lastSampledEpoch else { continue }

                let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
                guard now &- since >= config.triggerNanos else { continue }

                lastSampledEpoch = since  // one snapshot per stall episode
                captureSample()
            }
        }

        private func captureSample() {
            let pre = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
            let backtrace = EmbraceBacktrace.backtrace(of: config.mainThread, threadIndex: 0)  // suspends main; alloc-free
            let post = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

            let sample = MainThreadStackSample(
                timestamp: backtrace.timestamp,
                overhead: post &- pre,
                backtrace: backtrace
            )
            shared.buffer.withLock {
                $0.append(sample)
                if $0.count > config.bufferCap {
                    $0.removeFirst($0.count - config.bufferCap)
                }
            }
        }

        private static func sleep(nanos: UInt64) {
            var ts = timespec(
                tv_sec: Int(nanos / 1_000_000_000),
                tv_nsec: Int(nanos % 1_000_000_000)
            )
            nanosleep(&ts, nil)
        }
    }

#endif
