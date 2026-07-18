//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation  // URL / FileManager / String(format:) — used in the public API and file-backed paths

#if !os(watchOS)
    import Darwin

    // Under CocoaPods every subspec compiles into the single EmbraceIO module, so these
    // sibling modules must not be imported by name — see EmbraceIO.podspec.
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceAtomicsShim
        import EmbraceProfilingSampler
    #endif
#endif

/// A sampling-based profiling engine that captures main thread stack traces
/// at configurable intervals.
///
/// The engine can be started before SDK initialization (e.g., for startup profiling)
/// and samples can be retrieved after the engine has stopped.
///
/// - Note: On watchOS this is a no-op; Mach thread APIs are unavailable.
/// Concurrency contract: all mutable state (`ringBuffer`, `readBuffer`,
/// `readBufferSize`) is protected by `gate` (atomic CAS flag). The C sampler
/// manages its own thread safety via atomic state machine transitions.
///
/// **IMPORTANT:** Do NOT replace the gate with `os_unfair_lock` or any lock
/// with kernel ownership tracking. The sampler worker thread calls
/// `thread_suspend` on the main thread. If the main thread holds an
/// `os_unfair_lock` when suspended, any thread that tries to acquire that
/// lock will deadlock. The kernel knows the owner is suspended and will
/// never schedule the waiter. With a plain atomic CAS gate, waiters spin
/// briefly and time out, avoiding deadlock. This two-layer design (Swift
/// atomic gate + C atomic state machine + ring buffer seqlock) is intentional.
public final class ProfilingEngine: @unchecked Sendable {
    public static let shared = ProfilingEngine()

    /// File extension (without the leading dot) for a persisted profiling session file.
    internal static let sessionFileExtension = "embprof"

    /// Result of calling ``start(configuration:)``.
    public enum StartResult: Equatable, Sendable {
        /// Successfully started the sampler.
        case started
        /// Was already running.
        case alreadyActive
        /// Another caller is currently starting.
        case operationInProgress
        /// Ring buffer allocation failed.
        case bufferCreationFailed
        /// The provided configuration is invalid.
        case invalidConfiguration
        /// The underlying C sampler failed to start.
        case samplerStartFailed
        /// A previous sampler session is still shutting down. Try again later.
        case samplerBusy
        /// The sampler is already running with a different configuration.
        case configMismatch
        /// The sampler has entered an unrecoverable faulted state (bug or broken runtime).
        /// The associated string describes the fault reason.
        case faulted(reason: String)
        /// File-backed storage setup failed (open/ftruncate/mmap/mprotect). The associated
        /// string describes the cause (e.g. an errno). Only returned for file-backed starts.
        case storageSetupFailed(reason: String)
        /// Profiling is not supported on this platform (e.g. watchOS).
        case notSupported
    }

    /// Result of calling ``retrieveSamples(from:through:)``.
    public enum RetrieveResult: Equatable, Sendable {
        /// Samples were successfully retrieved (may be empty if none match the time range).
        case success(ProfilingResult)
        /// The engine has not been started (no buffers allocated).
        case notStarted
        /// Another operation (start or retrieve) is in progress. Retry shortly.
        case busy
        /// The sampler has entered an unrecoverable faulted state (bug or broken runtime).
        /// The associated string describes the fault reason.
        case faulted(reason: String)
        /// Profiling is not supported on this platform (e.g. watchOS).
        case notSupported
    }

    internal var activeConfiguration: ProfilingConfiguration?

    #if !os(watchOS)
        internal var ringBuffer: UnsafeMutablePointer<emb_ring_buffer_t>?
        internal var readBuffer: UnsafeMutableRawPointer?
        internal var readBufferSize: Int = 0
        /// File-backed store (persistent mode). nil for in-memory mode. When set, `ringBuffer`
        /// points into the store's mapping and is owned by the store, not the engine.
        internal var store: OpaquePointer?
        /// Filename of the active file-backed session (so `recoverableSessions(in:)` skips it). nil if in-memory.
        internal var activeSessionFileName: String?
        /// Atomic gate. CAS-based, no kernel ownership tracking.
        private let gateIsAcquired: UnsafeMutablePointer<emb_atomic_bool_t>
    #endif

    /// Sleep interval between gate acquisition attempts (nanoseconds).
    private static let gateSleepNs: UInt64 = 100_000
    /// Maximum cumulative actual uptime before giving up (nanoseconds). 10ms.
    private static let gateTimeoutNs: UInt64 = 10_000_000

    /// Returns `true` if the profiling engine is actively capturing stack traces.
    ///
    /// Equivalent to "the worker is in `RUNNING` and not paused". Returns
    /// `false` during transient states (`STARTING`, `STOPPING`), in `FAULTED`,
    /// when the engine has not been started, or when ``isPaused`` is `true`.
    /// To check whether the worker thread is still alive (for resource lifecycle
    /// purposes), use ``isActive``.
    public var isCapturing: Bool {
        #if os(watchOS)
            return false
        #else
            return emb_sampler_get_state() == EMB_SAMPLER_RUNNING
                && !emb_sampler_is_paused()
        #endif
    }

    /// Returns `true` if the sampler has entered an unrecoverable faulted state.
    public var isFaulted: Bool {
        #if os(watchOS)
            return false
        #else
            return emb_sampler_get_state() == EMB_SAMPLER_FAULTED
        #endif
    }

    /// Returns `true` if the sampler is in any active state (STARTING, RUNNING, or STOPPING).
    ///
    /// While `isActive` returns `true`, the worker thread may still be writing to the ring buffer.
    /// Use this (not ``isCapturing``) to determine when it is safe to destroy the ring buffer.
    /// Polling `isActive` also triggers background cleanup (thread join) when the worker exits.
    public var isActive: Bool {
        #if os(watchOS)
            return false
        #else
            return emb_sampler_is_active()
        #endif
    }

    /// Returns the fault reason if the sampler is faulted, or `nil` otherwise.
    public var faultReason: String? {
        #if os(watchOS)
            return nil
        #else
            guard let cStr = emb_sampler_get_fault_reason() else { return nil }
            return String(cString: cStr)
        #endif
    }

    private init() {
        #if !os(watchOS)
            self.gateIsAcquired = .allocate(capacity: 1)
            emb_atomic_bool_init(gateIsAcquired, false)
        #endif
    }

    #if !os(watchOS)
    /// Try to acquire the backing gate — the CAS flag guarding the engine's backing store and buffers
    /// (`ringBuffer`, `readBuffer`, `store`, …). Unrelated to the C sampler's own run-state machine.
    /// Sleeps ``gateSleepNs`` between attempts, up to ``gateTimeoutNs``
    /// cumulative actual elapsed time.
    ///
    /// Note: On iOS, timer coalescing may inflate `usleep(100)` to several
    /// milliseconds. Under contention, the effective behavior may be closer to
    /// 2-3 CAS attempts within the 10ms deadline rather than the ~100 attempts
    /// that the arithmetic suggests. This is acceptable because contention is
    /// expected to be extremely rare (only start/retrieve overlap).
    internal func acquireBackingGate() -> Bool {
        let deadlineNs = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) + Self.gateTimeoutNs
        while true {
            var expected: Bool = false
            if emb_atomic_bool_compare_exchange(gateIsAcquired, &expected, true, .acquire, .relaxed) {
                return true
            }
            if clock_gettime_nsec_np(CLOCK_UPTIME_RAW) >= deadlineNs {
                return false
            }
            usleep(useconds_t(Self.gateSleepNs / 1_000))
        }
    }

    /// Release the backing gate.
    internal func releaseBackingGate() {
        emb_atomic_bool_store(gateIsAcquired, false, .release)
    }
    #endif

    /// Start the profiling engine.
    ///
    /// Uses atomic CAS for fail-fast semantics: if another caller is
    /// mid-start, returns `.operationInProgress` immediately instead of
    /// blocking.
    ///
    /// - Note: This method acquires an internal gate using a sleep-based
    ///   spin loop (up to 10ms under contention). It is not suitable for
    ///   hot-path usage. Typical uncontested acquisition is sub-microsecond.
    ///
    /// - Parameter configuration: Profiling parameters. Defaults are suitable
    ///   for most use cases (10 Hz, 1MB buffer).
    /// - Returns: A ``StartResult`` indicating the outcome.
    /// Start sampling.
    ///
    /// - Parameters:
    ///   - configuration: profiling parameters.
    ///   - directory: when non-nil, samples are persisted to a file-backed buffer in this directory
    ///     (created if needed) so they survive a crash/Jetsam; recover them next launch via
    ///     `recoverableSessions(in:)` + `recover(_:)`. When nil, the buffer is in-memory (the default).
    ///   - sessionId: opaque 16-byte id for the file-backed session (becomes the filename). Must be
    ///     unique per launch. Ignored for in-memory mode; a random id is used if nil.
    ///
    /// - Important: A file-backed start (`directory != nil`) performs synchronous filesystem work on the
    ///   calling thread (`createDirectory`, `ftruncate`, `mmap`) and never dispatches internally — call
    ///   it off the main thread. In-memory mode (the default) does no filesystem I/O.
    /// - Note: For a file-backed session, on a *clean* stop call ``finalizeStorage()`` after the worker
    ///   has exited (poll ``isActive`` until `false`). Otherwise that session looks crash-like and is
    ///   listed by ``recoverableSessions(in:)`` on the next launch.
    @discardableResult
    public func start(configuration: ProfilingConfiguration = ProfilingConfiguration(),
                      directory: URL? = nil,
                      sessionId: [UInt8]? = nil) -> StartResult {
        #if os(watchOS)
            return .notSupported
        #else
            guard configuration.isValid else {
                return .invalidConfiguration
            }

            if let reason = faultReason {
                return .faulted(reason: reason)
            }

            guard acquireBackingGate() else {
                return .operationInProgress
            }
            defer { releaseBackingGate() }

            let wasActive = emb_sampler_is_active()

            // KNOWN RACE (dormant; no production caller of start() yet): is_active() is true for
            // STOPPING, and this Swift gate doesn't block the C worker's autonomous STOPPING→ZOMBIE
            // transition. If the worker finishes here, emb_sampler_start() below reaps the zombie and
            // wins a fresh CAS, so a genuinely new session reports .alreadyActive — and in file-backed
            // mode skips the setUpFileBackedBuffer branch, dropping the caller's sessionId. The real fix
            // is to have the C layer distinguish "fresh start" from "already running" in its return
            // instead of re-reading is_active() here; tracked as a follow-up.

            // Decide the backing. If the sampler is already active, leave it untouched (the worker
            // may be writing) and let emb_sampler_start() report the accurate state.
            let createdNewBacking: Bool
            if wasActive {
                createdNewBacking = false
            } else if let directory {
                // FILE-BACKED: a new session is a new file — always fresh, no reuse. Drop any prior
                // backing (in-memory buffer or a previous store) first.
                tearDownBacking()
                if let failure = setUpFileBackedBuffer(configuration: configuration,
                                                       directory: directory, sessionId: sessionId) {
                    return failure
                }
                createdNewBacking = true
            } else {
                // IN-MEMORY. If we were previously file-backed, drop the store first.
                if store != nil { tearDownBacking() }
                if let existing = ringBuffer,
                    configuration.bufferCapacityBytes == activeConfiguration?.bufferCapacityBytes {
                    // Same-capacity restart: reuse the buffer. Retry briefly — the Dekker protocol in
                    // reset can fail if a concurrent reader is briefly inside read_range.
                    var resetOK = false
                    for _ in 0..<3 {
                        if emb_ring_buffer_reset(existing) { resetOK = true; break }
                        usleep(200)
                    }
                    if !resetOK { return .samplerBusy }
                    createdNewBacking = false
                } else {
                    // First start, or capacity changed → fresh in-memory buffer.
                    if ringBuffer != nil { tearDownBacking() }
                    guard setUpInMemoryBuffer(configuration: configuration) else {
                        return .bufferCreationFailed
                    }
                    createdNewBacking = true
                }
            }

            let config = emb_sampler_config_t(
                sampling_interval_ms: configuration.samplingIntervalMs,
                min_sampling_interval_ms: configuration.minSamplingIntervalMs,
                max_frames: configuration.maxFramesPerSample,
                min_frames: configuration.minFramesPerSample,
                fallback_walker: nil,
                start_paused: configuration.startPaused
            )

            let startResult = emb_sampler_start(ringBuffer, config)

            if startResult != EMB_SAMPLER_START_OK, createdNewBacking {
                tearDownBacking()
            }

            switch startResult {
            case EMB_SAMPLER_START_OK:
                activeConfiguration = configuration
                return wasActive ? .alreadyActive : .started
            case EMB_SAMPLER_START_BUSY:
                // If the sampler was already active when we entered, BUSY means
                // it's in a transitional active state (STARTING/STOPPING), report
                // as already active. If it wasn't active, BUSY means a previous
                // session is still being reaped, so report as busy.
                return wasActive ? .alreadyActive : .samplerBusy
            case EMB_SAMPLER_START_CONFIG_MISMATCH:
                return .configMismatch
            default:
                if let reason = faultReason {
                    return .faulted(reason: reason)
                }
                return .samplerStartFailed
            }
        #endif
    }

    #if !os(watchOS)
    /// Tear down whatever backing exists (in-memory ring buffer or file-backed store) + the read buffer.
    /// For a store, this frees the attached ring-buffer wrapper and unmaps the file; it does NOT delete
    /// the file or write a tombstone (use `finalizeStorage()` for a clean stop).
    private func tearDownBacking() {
        if let s = store {
            emb_profile_store_destroy(s)  // frees the attached ring-buffer wrapper + unmaps
            store = nil
            ringBuffer = nil
        } else if let existing = ringBuffer {
            emb_ring_buffer_destroy(existing)
            ringBuffer = nil
        }
        if let ptr = readBuffer { free(ptr) }
        readBuffer = nil
        readBufferSize = 0
        activeConfiguration = nil
        activeSessionFileName = nil
    }

    /// Create a fresh in-memory ring buffer + read buffer. Returns false on allocation failure.
    private func setUpInMemoryBuffer(configuration: ProfilingConfiguration) -> Bool {
        guard let buffer = emb_ring_buffer_create(Int(configuration.bufferCapacityBytes), nil) else {
            return false
        }
        let capacity = emb_ring_buffer_capacity(buffer)
        guard let rb = malloc(capacity) else {
            emb_ring_buffer_destroy(buffer)
            return false
        }
        ringBuffer = buffer
        readBuffer = UnsafeMutableRawPointer(rb)
        readBufferSize = capacity
        return true
    }

    /// Create a file-backed store + read buffer in `directory`. Returns nil on success, or a failing
    /// `StartResult` on error (the engine is left with no backing).
    private func setUpFileBackedBuffer(configuration: ProfilingConfiguration,
                                       directory: URL,
                                       sessionId: [UInt8]?) -> StartResult? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return .storageSetupFailed(reason: "mkdir failed: \(error.localizedDescription)")
        }

        let sid = sessionId ?? (0..<16).map { _ in UInt8.random(in: 0...255) }
        guard sid.count == 16 else {
            return .storageSetupFailed(reason: "sessionId must be 16 bytes")
        }
        let fileName = sid.map { String(format: "%02x", $0) }.joined() + "." + Self.sessionFileExtension
        let path = directory.appendingPathComponent(fileName).path

        var err: Int32 = 0
        let storePtr: OpaquePointer? = path.withCString { cpath in
            sid.withUnsafeBufferPointer { sidBuf in
                emb_profile_store_create(cpath, Int(configuration.bufferCapacityBytes), sidBuf.baseAddress, &err)
            }
        }
        guard let storePtr else {
            return .storageSetupFailed(reason: "store create failed (errno \(err))")
        }
        guard let buf = emb_profile_store_buffer(storePtr) else {
            emb_profile_store_destroy(storePtr)
            return .storageSetupFailed(reason: "store buffer unavailable")
        }
        let capacity = emb_ring_buffer_capacity(buf)
        guard let rb = malloc(capacity) else {
            emb_profile_store_destroy(storePtr)
            return .storageSetupFailed(reason: "read-buffer allocation failed (\(capacity) bytes)")
        }
        store = storePtr
        ringBuffer = buf
        readBuffer = UnsafeMutableRawPointer(rb)
        readBufferSize = capacity
        activeSessionFileName = fileName
        return nil
    }
    #endif  // !os(watchOS)

    /// Flush persisted samples to disk (`msync(MS_ASYNC)`). No-op in in-memory mode. The CaptureService
    /// wrapper calls this on `willResignActive` / `didEnterBackground` (and `willTerminate`) so samples
    /// are durable before a possible background Jetsam kill. Cheap, non-blocking, off the hot path.
    ///
    /// - Note: Best-effort — it skips silently if the engine's gate is briefly contended (e.g. a
    ///   concurrent `start`/`retrieveSamples`). `MAP_SHARED` pages are still flushed by the kernel on
    ///   normal termination; this only matters for an abrupt Jetsam within that small window.
    /// - Note: `msync` runs concurrently with the live sampler writing the same mapping — this is by
    ///   design. A page captured mid-write is just re-flushed later, and recovery's seqlock/torn-tail
    ///   handling discards any partial record, so a torn flush is never observable as corruption.
    public func flush() {
        #if !os(watchOS)
            // Gate-protected: `store` is torn down (destroyed + niled) under the gate by start()/reset.
            // Without this, a background/terminate-thread flush could msync a freed/unmapped store.
            guard acquireBackingGate() else { return }
            defer { releaseBackingGate() }
            if let s = store { emb_profile_store_flush(s) }
        #endif
    }

    /// Mark the file-backed session cleanly finalized (writes the version-0 tombstone), so recovery
    /// reports nothing for it. No-op in in-memory mode. Call on a clean stop, after the worker has
    /// exited (poll `isActive` until false) — the wrapper sequences this.
    ///
    /// - Important: This DISCARDS the session's on-disk samples — the tombstone marks the *entire* file
    ///   "disregard". Only call it once you have retrieved everything you need (e.g. via
    ///   ``retrieveSamples(from:through:)``); there is no recovery after finalize.
    /// - Important: This is a NO-OP while sampling is still active. Writing the tombstone before the
    ///   worker has drained would silently discard not-yet-reported samples, so if called early it
    ///   leaves the session recoverable (reported next launch) rather than lost. Conversely, if you
    ///   never call it on a clean stop, that session is listed by ``recoverableSessions(in:)`` next
    ///   launch (a harmless false positive you can ``delete(_:)``).
    public func finalizeStorage() {
        #if !os(watchOS)
            // Gate-protected for the same reason as flush(): guards against a concurrent store teardown.
            guard acquireBackingGate() else { return }
            defer { releaseBackingGate() }
            // Refuse to tombstone a live buffer (see note above) — leave it recoverable instead.
            guard !emb_sampler_is_active() else { return }
            if let s = store { emb_profile_store_finalize(s) }
        #endif
    }

    /// Request the profiling engine to stop.
    ///
    /// This is non-blocking: it signals the worker thread to exit and
    /// returns immediately. To determine when it is safe to destroy the ring buffer (or when the worker
    /// has fully exited), poll ``isActive`` until it returns `false`. ``isCapturing``
    /// flips to `false` as soon as STOPPING begins and is not sufficient for this purpose.
    ///
    /// Samples captured before stopping remain available via ``retrieveSamples(from:through:)``.
    public func stop() {
        #if !os(watchOS)
            emb_sampler_stop()
        #endif
    }

    /// Pause the engine without tearing down the worker thread.
    ///
    /// While paused, the worker thread continues to wake on its configured
    /// cadence but skips the main-thread suspend, stack walk, and ring buffer
    /// write. Existing samples remain readable via
    /// ``retrieveSamples(from:through:)``.
    ///
    /// Pause/resume bypass the engine gate, so they are safe to call at high
    /// frequency (e.g. from span boundaries). The cost is a single relaxed
    /// atomic store per call.
    ///
    /// Observation latency is bounded by the sampling interval: the worker
    /// observes the pause flag at the top of each loop iteration. A pause
    /// request mid-sleep takes effect at the next wake-up, which guarantees
    /// the configured sampling interval is also a hard cap on main-thread
    /// suspension frequency.
    ///
    /// Idempotent: pausing an already-paused engine returns `true`. Safe to
    /// call synchronously after ``start(configuration:)`` (the underlying C
    /// API accepts both `STARTING` and `RUNNING`).
    ///
    /// Nesting/refcounting (e.g. for overlapping spans) is the caller's
    /// responsibility; pause and resume are simple toggles, not counters.
    ///
    /// - Returns: `true` if the pause flag was set (engine is in `STARTING`
    ///   or `RUNNING`). `false` if the engine is not in a state where pause
    ///   is meaningful (not started, stopping, or faulted).
    @discardableResult
    public func pause() -> Bool {
        #if os(watchOS)
            return false
        #else
            return emb_sampler_pause()
        #endif
    }

    /// Resume sampling after a pause.
    ///
    /// See ``pause()`` for semantics. Resume is symmetric: a single relaxed
    /// atomic store, gate-free, safe at high frequency. The next sample is
    /// taken at the worker's next configured wake-up.
    ///
    /// Idempotent: resuming an already-running engine returns `true`. Safe
    /// to call synchronously after `start(configuration:)` with
    /// `startPaused: true`.
    ///
    /// - Returns: `true` if the pause flag was cleared (engine is in
    ///   `STARTING` or `RUNNING`). `false` if the engine is not in a state
    ///   where resume is meaningful.
    @discardableResult
    public func resume() -> Bool {
        #if os(watchOS)
            return false
        #else
            return emb_sampler_resume()
        #endif
    }

    /// Returns `true` if the engine is currently paused.
    ///
    /// Gated on `RUNNING || STARTING` — the only states where the pause flag
    /// has any effect on the worker. After `stop()` (or in `FAULTED`), this
    /// returns `false` regardless of the underlying flag value, so the user
    /// never sees a stale `true` on an inactive engine.
    public var isPaused: Bool {
        #if os(watchOS)
            return false
        #else
            let state = emb_sampler_get_state()
            return (state == EMB_SAMPLER_RUNNING || state == EMB_SAMPLER_STARTING)
                && emb_sampler_is_paused()
        #endif
    }

    /// Retrieve profiling samples within the given time range.
    ///
    /// Time values are in `CLOCK_MONOTONIC_RAW` nanoseconds, matching timekeeping used in EmbraceClock.swift.
    ///
    /// Samples are returned in chronological order. The engine does not need to be running.
    /// Samples persist after ``stop()`` is called, and persist across calls to
    /// ``start(configuration:)`` that reuse the same buffer. Samples are cleared
    /// when ``start(configuration:)`` allocates a new buffer (different capacity or first start).
    ///
    /// - Note: This method acquires an internal gate using a sleep-based
    ///   spin loop (up to 10ms under contention). It is not suitable for
    ///   hot-path usage. Typical uncontested acquisition is sub-microsecond.
    ///   With only 1 reader, contention will be minimal and rare.
    ///
    /// - Parameters:
    ///   - startTime: Start of the time range (`CLOCK_MONOTONIC_RAW` nanoseconds).
    ///   - endTime: End of the time range (`CLOCK_MONOTONIC_RAW` nanoseconds).
    /// - Returns: A ``RetrieveResult`` indicating the outcome.
    public func retrieveSamples(from startTime: UInt64, through endTime: UInt64) -> RetrieveResult {
        #if os(watchOS)
            return .notSupported
        #else
            if let reason = faultReason {
                return .faulted(reason: reason)
            }

            guard acquireBackingGate() else { return .busy }
            defer { releaseBackingGate() }

            guard let ringBuffer, let readBuffer else {
                return .notStarted
            }

            let result = emb_ring_buffer_read_range(ringBuffer, startTime, endTime,
                                                    readBuffer.assumingMemoryBound(to: UInt8.self),
                                                    readBufferSize)

            guard result.record_count > 0 else {
                return .success(ProfilingResult(samples: [], frames: []))
            }

            let headerSize = MemoryLayout<emb_ring_record_header_t>.size
            let rawBuffer = UnsafeRawPointer(readBuffer)

            // Valid data boundary: only records_offset..records_offset+total_bytes
            // contains data copied from the ring buffer. Checking against
            // readBufferSize would allow reading stale data beyond the copy range.
            let validEnd = Int(result.records_offset) + Int(result.total_bytes)

            // Pass 1: Walk records to count total frames for upfront allocation.
            var totalFrames = 0
            var offset = result.records_offset
            for _ in 0..<result.record_count {
                guard offset + headerSize <= validEnd else { break }
                let header = rawBuffer.load(fromByteOffset: offset, as: emb_ring_record_header_t.self)
                // Defense-in-depth: reject implausibly large frame_count values.
                // The C read path already bounds-checks via record_size > (write_pos -
                // scan_pos), but a corruption check is cheap.
                guard Int(header.frame_count) <= Int(EMB_MAX_STACK_FRAMES) else { break }
                let recordSize = Int(emb_ring_record_size(UInt32(header.frame_count)))
                guard offset + recordSize <= validEnd else { break }
                totalFrames += Int(header.frame_count)
                offset += recordSize
            }

            // Pass 2: Allocate once, then populate.
            var samples: [ProfilingSample] = []
            samples.reserveCapacity(result.record_count)
            var frames: [UInt] = []
            frames.reserveCapacity(totalFrames)

            offset = result.records_offset
            for _ in 0..<result.record_count {
                guard offset + headerSize <= validEnd else { break }
                let header = rawBuffer.load(fromByteOffset: offset, as: emb_ring_record_header_t.self)
                guard Int(header.frame_count) <= Int(EMB_MAX_STACK_FRAMES) else { break }
                let frameCount = Int(header.frame_count)
                let recordSize = Int(emb_ring_record_size(UInt32(header.frame_count)))
                guard offset + recordSize <= validEnd else { break }

                let framesStart = frames.count
                // Invariant: uintptr_t and UInt are both 8 bytes on all supported
                // platforms (64-bit only). The _Static_assert in emb_ring_buffer.h
                // enforces this at the C layer. This assumingMemoryBound is safe
                // because the ring buffer stores uintptr_t values at this offset.
                let framesPtr = (rawBuffer + offset + headerSize)
                    .assumingMemoryBound(to: UInt.self)
                frames.append(contentsOf: UnsafeBufferPointer(start: framesPtr, count: frameCount))

                samples.append(ProfilingSample(
                    timestamp: header.timestamp_ns,
                    frameRange: framesStart..<frames.count,
                    threadState: ThreadState(rawValue: header.thread_state) ?? .unknown
                ))

                offset += recordSize
            }

            return .success(ProfilingResult(samples: samples, frames: frames))
        #endif
    }

    // Note: ProfilingEngine is a singleton; deinit never runs.
    // If changed to non-singleton, deinit would need to:
    //   1. Call emb_sampler_stop(), then poll emb_sampler_is_active() until
    //      false (with a timeout to avoid unbounded blocking).
    //   2. Destroy the ring buffer: emb_ring_buffer_destroy(ringBuffer)
    //   3. Deallocate readBuffer: if let ptr = readBuffer { free(ptr) }
    //   4. Deallocate the atomic gate:
    //      gateIsAcquired.deallocate()
}
