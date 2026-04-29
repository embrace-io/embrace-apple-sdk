//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)
    @testable import EmbraceProfiling
    import EmbraceProfilingSampler
    import EmbraceProfilingTestSupport
#endif

extension ProfilingEngine {

    /// TEST-ONLY: Allocate the ring buffer without starting the sampler.
    /// Allows writing synthetic data via ``writeSampleForTesting(timestamp:frames:)``
    /// then reading via ``retrieveSamples(from:through:)``.
    /// Acquires the gate. Returns false on allocation failure, invalid config, or gate contention.
    func allocateBufferForTesting(
        configuration: ProfilingConfiguration = ProfilingConfiguration()
    ) -> Bool {
        #if os(watchOS)
            return false
        #else
            guard configuration.isValid else { return false }
            guard acquireGate() else { return false }
            defer { releaseGate() }

            guard !emb_sampler_is_active() else { return false }

            // Tear down any existing buffer if capacity changed.
            if let existing = ringBuffer {
                if configuration.bufferCapacityBytes == activeConfiguration?.bufferCapacityBytes {
                    if !emb_ring_buffer_reset(existing) {
                        return false
                    }
                } else {
                    emb_ring_buffer_destroy(existing)
                    if let ptr = readBuffer { free(ptr) }
                    ringBuffer = nil
                    readBuffer = nil
                    readBufferSize = 0
                }
            }

            if ringBuffer == nil {
                guard let buffer = emb_ring_buffer_create(Int(configuration.bufferCapacityBytes)) else {
                    return false
                }
                ringBuffer = buffer

                let capacity = emb_ring_buffer_capacity(buffer)
                guard let newReadBuffer = malloc(capacity) else {
                    emb_ring_buffer_destroy(buffer)
                    ringBuffer = nil
                    return false
                }
                readBuffer = UnsafeMutableRawPointer(newReadBuffer)
                readBufferSize = capacity
            }

            activeConfiguration = configuration
            return true
        #endif
    }

    /// TEST-ONLY: Write a synthetic sample directly to the ring buffer.
    /// Buffer must have been allocated (via ``allocateBufferForTesting(configuration:)`` or ``start(configuration:)``).
    /// Does NOT acquire the gate. Caller must ensure no concurrent access.
    func writeSampleForTesting(timestamp: UInt64, frames: [UInt]) -> Bool {
        #if os(watchOS)
            return false
        #else
            guard let ringBuffer else { return false }

            return frames.withUnsafeBufferPointer { buf in
                guard let baseAddress = buf.baseAddress else { return false }
                return baseAddress.withMemoryRebound(to: uintptr_t.self, capacity: frames.count) { ptr in
                    emb_ring_buffer_write(ringBuffer, timestamp, ptr, frames.count)
                }
            }
        #endif
    }

    /// TEST-ONLY: Reset the engine to a clean initial state.
    /// Stops sampler if active (with polling wait), destroys ring buffer,
    /// deallocates read buffer, resets C sampler state.
    /// Acquires the gate.
    func resetForTesting() {
        #if !os(watchOS)
            emb_sampler_stop()

            let deadline = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) + 5_000_000_000
            while emb_sampler_is_active() {
                if clock_gettime_nsec_np(CLOCK_UPTIME_RAW) >= deadline { break }
                usleep(1000)
            }

            guard !emb_sampler_is_active() else {
                preconditionFailure("resetForTesting: sampler still active after 5s timeout")
            }

            // Best-effort gate acquisition: if it times out we still clean up
            // since we've already stopped the sampler.
            let gateAcquired = acquireGate()

            if let rb = ringBuffer {
                emb_ring_buffer_destroy(rb)
                ringBuffer = nil
            }
            if let rb = readBuffer {
                free(rb)
                readBuffer = nil
            }
            readBufferSize = 0
            activeConfiguration = nil

            emb_sampler_reset_for_testing()

            if gateAcquired {
                releaseGate()
            }
        #endif
    }
}
