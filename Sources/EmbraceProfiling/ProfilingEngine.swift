//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)
    import Darwin
    import EmbraceAtomicsShim
    import EmbraceProfilingSampler
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

    /// Result of calling ``start(configuration:)``.
    public enum StartResult: Equatable {
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
        /// Profiling is not supported on this platform (e.g. watchOS).
        case notSupported
    }

    /// Result of calling ``retrieveSamples(from:through:)``.
    public enum RetrieveResult {
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
        /// Atomic gate. CAS-based, no kernel ownership tracking.
        private let gateIsAcquired: UnsafeMutablePointer<emb_atomic_bool_t>
    #endif

    /// Sleep interval between gate acquisition attempts (microseconds).
    private static let gateSleepUs: useconds_t = 100
    /// Maximum cumulative actual uptime before giving up (nanoseconds). 10ms.
    private static let gateMaxSleepNs: UInt64 = 10_000_000

    /// Returns `true` if the profiling engine is actively capturing stack traces.
    ///
    /// This checks for the `RUNNING` state specifically. It does not return
    /// `true` during transient states like `STARTING` or `STOPPING`.
    public var isCapturing: Bool {
        #if os(watchOS)
            return false
        #else
            return emb_sampler_get_state() == EMB_SAMPLER_RUNNING
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
    /// Try to acquire the gate.
    /// Sleeps ``gateSleepUs`` between attempts, up to ``gateMaxSleepNs``
    /// cumulative actual elapsed time, then one final attempt (in case actual
    /// sleeps were substantially longer than requested and we got fewer attempts
    /// than expected).
    ///
    /// Note: On iOS, timer coalescing may inflate `usleep(100)` to several
    /// milliseconds. Under contention, the effective behavior may be closer to
    /// 2-3 CAS attempts within the 10ms deadline rather than the ~100 attempts
    /// that the arithmetic suggests. This is acceptable because contention is
    /// expected to be extremely rare (only start/retrieve overlap).
    internal func acquireGate() -> Bool {
        let deadlineNs = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) + Self.gateMaxSleepNs
        while true {
            var expected: Bool = false
            if emb_atomic_bool_compare_exchange(gateIsAcquired, &expected, true, .acquire, .relaxed) {
                return true
            }
            if clock_gettime_nsec_np(CLOCK_UPTIME_RAW) >= deadlineNs {
                return false
            }
            usleep(Self.gateSleepUs)
        }
    }

    /// Release the gate.
    internal func releaseGate() {
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
    @discardableResult
    public func start(configuration: ProfilingConfiguration = ProfilingConfiguration()) -> StartResult {
        #if os(watchOS)
            return .notSupported
        #else
            guard configuration.isValid else {
                return .invalidConfiguration
            }

            if let reason = faultReason {
                return .faulted(reason: reason)
            }

            guard acquireGate() else {
                return .operationInProgress
            }
            defer { releaseGate() }

            guard !emb_sampler_is_active() else { return .alreadyActive }

            let needsNewBuffer: Bool
            if let existing = ringBuffer {
                if configuration.bufferCapacityBytes == activeConfiguration?.bufferCapacityBytes {
                    // Retry briefly: the Dekker protocol in reset can fail if a
                    // concurrent reader is briefly inside read_range. Under the
                    // Swift gate this is unlikely, but defensive retries are cheap.
                    var resetOK = false
                    for _ in 0..<3 {
                        if emb_ring_buffer_reset(existing) {
                            resetOK = true
                            break
                        }
                        usleep(200)
                    }
                    if !resetOK {
                        return .samplerBusy
                    }
                    needsNewBuffer = false
                } else {
                    emb_ring_buffer_destroy(existing)
                    if let ptr = readBuffer { free(ptr) }
                    activeConfiguration = nil
                    ringBuffer = nil
                    readBuffer = nil
                    readBufferSize = 0
                    needsNewBuffer = true
                }
            } else {
                needsNewBuffer = true
            }

            if needsNewBuffer {
                guard let buffer = emb_ring_buffer_create(Int(configuration.bufferCapacityBytes)) else {
                    return .bufferCreationFailed
                }
                ringBuffer = buffer

                let capacity = emb_ring_buffer_capacity(buffer)
                guard let newReadBuffer = malloc(capacity) else {
                    emb_ring_buffer_destroy(buffer)
                    ringBuffer = nil
                    return .bufferCreationFailed
                }
                readBuffer = UnsafeMutableRawPointer(newReadBuffer)
                readBufferSize = capacity
            }

            let config = emb_sampler_config_t(
                sampling_interval_ms: configuration.samplingIntervalMs,
                min_sampling_interval_ms: configuration.minSamplingIntervalMs,
                max_frames: configuration.maxFramesPerSample,
                min_frames: 0,
                fallback_walker: nil
            )

            switch emb_sampler_start(ringBuffer, config) {
            case EMB_SAMPLER_START_OK:
                activeConfiguration = configuration
                return .started
            case EMB_SAMPLER_START_BUSY:
                return .samplerBusy
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

    /// Request the profiling engine to stop.
    ///
    /// This is non-blocking: it signals the worker thread to exit and
    /// returns immediately. Poll ``isCapturing`` to determine when the
    /// worker has actually stopped.
    ///
    /// Samples captured before stopping remain available via ``retrieveSamples(from:through:)``.
    public func stop() {
        #if !os(watchOS)
            emb_sampler_stop()
        #endif
    }

    /// Retrieve profiling samples within the given time range.
    ///
    /// Time values are in `CLOCK_MONOTONIC_RAW` nanoseconds, matching timekeeping used in EmbraceClock.swift.
    ///
    /// Samples are returned in chronological order. The engine does not need to be running.
    /// Samples persist after ``stop()`` is called, but are cleared on ``start(configuration:)``.
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

            guard acquireGate() else { return .busy }
            defer { releaseGate() }

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
                guard header.frame_count <= UInt32(EMB_MAX_STACK_FRAMES) else { break }
                let recordSize = Int(emb_ring_record_size(header.frame_count))
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
                guard header.frame_count <= UInt32(EMB_MAX_STACK_FRAMES) else { break }
                let frameCount = Int(header.frame_count)
                let recordSize = Int(emb_ring_record_size(header.frame_count))
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
                    frameRange: framesStart..<frames.count
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
    //   4. Deinitialize and deallocate the atomic gate:
    //      emb_atomic_bool_deinit(gateIsAcquired)
    //      gateIsAcquired.deallocate()
}
