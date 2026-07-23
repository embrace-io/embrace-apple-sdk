//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import Foundation

    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
    #endif

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

        /// Lower bound on the trigger. Prevents a bad/hostile remote value from driving overly
        /// aggressive main-thread suspension.
        static let minTriggerThreshold: TimeInterval = 0.05  // 50 ms

        /// Lower bound on the poll cadence, for the same reason.
        static let minPollInterval: TimeInterval = 0.01  // 10 ms

        private let mainThread: pthread_t
        private let triggerNanos: UInt64
        private let pollMicros: useconds_t
        private let bufferCap: Int
        private weak var logger: InternalLogger?

        /// `CLOCK_MONOTONIC_RAW` ns when the current busy epoch began; `0` when the run loop is idle.
        /// Written by the main-thread beacon, read by the background poller.
        private let busySince = EmbraceAtomic<UInt64>(0)
        private let paused = EmbraceAtomic<Bool>(false)
        private let running = EmbraceAtomic<Bool>(false)

        private let buffer = EmbraceMutex<[MainThreadStackSample]>([])

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
        ///   - mainThread: the `pthread_t` of the thread to sample (the main thread).
        ///   - triggerThreshold: how long main must be continuously busy before we snapshot it.
        ///     Clamped up to ``minTriggerThreshold``.
        ///   - pollInterval: how often the background thread checks liveness. Clamped up to
        ///     ``minPollInterval``.
        ///   - bufferCap: max buffered samples (small ring; one per stall episode).
        init(
            mainThread: pthread_t,
            triggerThreshold: TimeInterval,
            pollInterval: TimeInterval = 0.05,
            bufferCap: Int = 8,
            logger: InternalLogger?
        ) {
            self.mainThread = mainThread
            self.triggerNanos = UInt64(max(Self.minTriggerThreshold, triggerThreshold) * 1_000_000_000)
            self.pollMicros = useconds_t(max(Self.minPollInterval, pollInterval) * 1_000_000)
            self.bufferCap = bufferCap
            self.logger = logger
        }

        /// Convenience: derive the trigger from the reported-hang threshold (a fraction below it so
        /// the snapshot lands in-window even for short hangs).
        convenience init(mainThread: pthread_t, hangThreshold: TimeInterval, logger: InternalLogger?) {
            self.init(
                mainThread: mainThread,
                triggerThreshold: hangThreshold * 0.6,
                logger: logger
            )
        }

        deinit { stop() }

        /// Effective trigger after clamping, in seconds. Exposed for tests.
        var effectiveTriggerThreshold: TimeInterval { TimeInterval(triggerNanos) / 1_000_000_000 }

        /// Effective poll cadence after clamping, in seconds. Exposed for tests.
        var effectivePollInterval: TimeInterval { TimeInterval(pollMicros) / 1_000_000 }

        // MARK: - MainThreadStackSampler

        func start() {
            lifecycle.withLock { state in
                guard !running.load(order: .acquire) else { return }
                running.store(true, order: .release)

                if let observer = makeObserver() {
                    state.observer = observer
                    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
                }
                state.tokens = makeLifecycleTokens()

                let thread = Thread { [weak self] in self?.run() }
                thread.name = "io.embrace.hang.sampler"
                thread.qualityOfService = .userInitiated
                state.thread = thread
                thread.start()
            }
        }

        func stop() {
            lifecycle.withLock { state in
                guard running.load(order: .acquire) else { return }
                running.store(false, order: .release)

                if let observer = state.observer {
                    CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
                }
                state.observer = nil

                let nc = NotificationCenter.default
                state.tokens.forEach { nc.removeObserver($0) }
                state.tokens = []

                state.thread = nil
                busySince.store(0, order: .release)
            }
        }

        func pause() {
            paused.store(true, order: .release)
            busySince.store(0, order: .release)  // forget the current epoch across background
        }

        func resume() {
            busySince.store(0, order: .release)  // fresh start; the beacon repopulates it
            paused.store(false, order: .release)
        }

        func samples(in range: ClosedRange<UInt64>) -> [MainThreadStackSample] {
            buffer.withLock { $0.filter { range.contains($0.timestamp) } }
        }

        // MARK: - Main-thread liveness beacon

        private func makeObserver() -> CFRunLoopObserver? {
            let activities = CFRunLoopActivity([.afterWaiting, .beforeWaiting]).rawValue
            return CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, activities, true, 0) {
                [weak self] _, activity in
                guard let self else { return }
                if activity == .beforeWaiting {
                    self.busySince.store(0, order: .release)  // going idle → not a hang
                } else {
                    // .afterWaiting → a busy epoch begins. One atomic store, nothing else.
                    self.busySince.store(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW), order: .release)
                }
            }
        }

        // MARK: - Background sampling loop

        private func run() {
            // The `busySince` value we last captured for. Poller-local: no synchronization needed.
            var lastSampledEpoch: UInt64 = 0

            while running.load(order: .acquire) {
                usleep(pollMicros)

                guard !paused.load(order: .acquire) else { continue }

                let since = busySince.load(order: .acquire)
                guard since != 0, since != lastSampledEpoch else { continue }

                let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
                guard now &- since >= triggerNanos else { continue }

                lastSampledEpoch = since  // one snapshot per stall episode
                captureSample()
            }
        }

        private func captureSample() {
            guard EmbraceBacktrace.isAvailable else { return }

            let pre = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
            let backtrace = EmbraceBacktrace.backtrace(of: mainThread, threadIndex: 0)  // suspends main; alloc-free
            let post = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)

            let sample = MainThreadStackSample(
                timestamp: backtrace.timestamp,
                overhead: post &- pre,
                backtrace: backtrace
            )
            buffer.withLock {
                $0.append(sample)
                if $0.count > bufferCap {
                    $0.removeFirst($0.count - bufferCap)
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

#endif
