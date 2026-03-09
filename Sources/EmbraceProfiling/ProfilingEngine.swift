//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS)
    import Darwin
    import EmbraceProfilingSampler
#endif

/// A sampling-based profiling engine that captures main thread stack traces
/// at configurable intervals.
///
/// The engine can be started before SDK initialization (e.g., for startup profiling)
/// and samples can be retrieved after the engine has stopped.
///
/// - Note: On watchOS this is a no-op; Mach thread APIs are unavailable.
public final class ProfilingEngine {
    private let configuration: ProfilingConfiguration

    #if !os(watchOS)
        private var _isRunning = false
        private var startTimestamp: UInt64 = 0
        private var stopTimestamp: UInt64 = 0
    #endif

    /// Returns `true` if the profiling engine is currently running.
    public var isRunning: Bool {
        #if os(watchOS)
            return false
        #else
            return _isRunning
        #endif
    }

    public init() {
        self.configuration = ProfilingConfiguration()
    }

    /// Start the profiling engine.
    ///
    /// Calling `start` while already running has no effect.
    ///
    /// - Throws: An error if the underlying sampler cannot be initialized.
    public func start() throws {
        #if os(watchOS)
            // No-op on watchOS
        #else
            guard !_isRunning else { return }
            startTimestamp = currentTimestampNs()
            stopTimestamp = 0
            _isRunning = true
        #endif
    }

    /// Stop the profiling engine.
    ///
    /// Samples captured before stopping remain available via ``retrieveSamples(from:through:)``.
    public func stop() {
        #if os(watchOS)
            // No-op on watchOS
        #else
            guard _isRunning else { return }
            stopTimestamp = currentTimestampNs()
            _isRunning = false
        #endif
    }

    /// Retrieve profiling samples within the given time range.
    ///
    /// Time values are in `CLOCK_MONOTONIC_RAW` nanoseconds, matching timekeeping used in EmbraceClock.swift.
    ///
    /// Samples are returned in chronological order. The engine does not need to be running.
    /// Samples persist after ``stop()`` is called.
    ///
    /// - Parameters:
    ///   - startTime: Start of the time range (`CLOCK_MONOTONIC_RAW` nanoseconds).
    ///   - endTime: End of the time range (`CLOCK_MONOTONIC_RAW` nanoseconds).
    /// - Returns: An array of `ProfilingSample` values captured within the range.
    public func retrieveSamples(from startTime: UInt64, through endTime: UInt64) -> [ProfilingSample] {
        #if os(watchOS)
            return []
        #else
            return generateFakeSamples(from: startTime, through: endTime)
        #endif
    }

    // MARK: - Prototype fake data (will be replaced by real sampler)

    #if !os(watchOS)
        private func currentTimestampNs() -> UInt64 {
            clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        }

        private func generateFakeSamples(from startTime: UInt64, through endTime: UInt64) -> [ProfilingSample] {
            guard startTimestamp > 0 else { return [] }

            let effectiveEnd: UInt64
            if _isRunning {
                effectiveEnd = currentTimestampNs()
            } else if stopTimestamp > 0 {
                effectiveEnd = stopTimestamp
            } else {
                return []
            }

            let rangeStart = max(startTime, startTimestamp)
            let rangeEnd = min(endTime, effectiveEnd)
            guard rangeStart < rangeEnd else { return [] }

            let intervalNs = UInt64(configuration.samplingIntervalMs) * 1_000_000
            var samples: [ProfilingSample] = []

            var tick = startTimestamp + intervalNs
            while tick <= rangeEnd {
                if tick >= rangeStart {
                    samples.append(
                        ProfilingSample(
                            timestamp: tick,
                            frames: fakeSampleFrames(seed: tick)
                        ))
                }
                tick += intervalNs
            }

            return samples
        }

        private func fakeSampleFrames(seed: UInt64) -> [UInt64] {
            // Simulate main thread call stacks with realistic arm64 addresses.

            // Usually the base will look like this:
            let runLoopBase: [UInt64] = [
                0x00000001_8B6E6000,  // CoreFoundation: CFRunLoopRunSpecific
                0x00000001_8B6E5800,  // CoreFoundation: __CFRunLoopRun
                0x00000001_8B6E2400,  // CoreFoundation: __CFRunLoopDoSources0
                0x00000001_8B6E1000,  // CoreFoundation: __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0
                0x00000001_8DAF4200,  // CoreAnimation: CA::Display::DisplayLink::dispatch
                0x00000001_8DAF2100,  // CoreAnimation: CA::Transaction::commit
                0x00000001_8E301C80,  // UIKitCore: -[UIApplication _firstCommitBlock]
                0x00000001_8E2F3B40,  // UIKitCore: -[UIApplication _run]
                0x00000001_8E2F1A00,  // UIKitCore: UIApplicationMain
                0x00000001_04A3D210,  // app: UIApplicationMain wrapper
                0x00000001_04A3C000  // app: main
            ]

            // Varying stack tops
            var top: [UInt64]
            switch seed % 5 {
            case 0:
                top = [
                    0x00000001_04A42300,  // app: -[ViewController loadData]
                    0x00000001_04A42100  // app: -[ViewController viewDidLoad]
                ]
            case 1:
                top = [
                    0x00000001_04A45200,  // app: completion handler
                    0x00000001_04A45000  // app: -[NetworkManager fetch]
                ]
            case 2:
                top = [
                    0x00000001_04A48000  // app: -[TableView cellForRow]
                ]
            case 3:
                top = [
                    0x00000001_04A4B400,  // app: -[AnimationController render]
                    0x00000001_04A4B200,  // app: -[AnimationController update]
                    0x00000001_04A4B000  // app: -[AnimationController tick]
                ]
            default:
                top = [
                    0x00000001_04A4E000  // app: -[LayoutEngine solve]
                ]
            }

            return top + runLoopBase
        }
    #endif
}
