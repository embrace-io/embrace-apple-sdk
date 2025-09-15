//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

/// ALL TIMES IN NANOSECONDS

public typealias EmbraceProfileIdentifier = String

public struct EmbraceProfile: Codable {
    public let id: EmbraceProfileIdentifier
    public let name: String
    public let backtraces: [EmbraceBacktrace]
    public let interval: UInt64
    public let startTime: UInt64
    public let endTime: UInt64
}

extension EmbraceProfile: Equatable {
    public static func == (lhs: EmbraceProfile, rhs: EmbraceProfile) -> Bool {
        lhs.id == rhs.id
    }
}

extension EmbraceProfile: Identifiable {}
extension EmbraceProfile: Sendable {}

public class EmbraceProfiler {

    private struct MutableData {
        var backtraces: [EmbraceBacktrace] = []
        var profiles: [EmbraceProfileIdentifier: EmbraceProfile_Internal] = [:]
        var timer: DispatchSourceTimer?
    }
    private let data = EmbraceMutex(MutableData())
    private let mainThead: pthread_t
    private let queue: DispatchQueue
    private let completionQueue: DispatchQueue
    private let interval: UInt64

    static public let profiler = EmbraceProfiler()

    private init() {
        self.queue = DispatchQueue(label: "com.embrace.profiler")
        self.completionQueue = DispatchQueue(label: "com.embrace.profiler.completion")
        self.interval = 1 * NSEC_PER_MSEC
        self.mainThead =
            if Thread.isMainThread {
                pthread_self()
            } else {
                DispatchQueue.main.sync { pthread_self() }
            }
    }

    private func locked_beginProfilerIfNeeded(_ mutableData: inout MutableData) {
        guard mutableData.profiles.count == 1 else {
            return
        }

        // begin profiling
        mutableData.timer = DispatchSource.makeTimerSource(queue: queue)
        mutableData.timer?.setEventHandler { [weak self] in
            guard let self else { return }
            let backtrace = EmbraceBacktrace.backtrace(of: self.mainThead, suspendingThreads: false)
            self.data.withLock {
                $0.backtraces.append(backtrace)
            }
        }
        mutableData.timer?.schedule(deadline: .now(), repeating: .nanoseconds(Int(interval)))
        mutableData.timer?.activate()
    }

    private func locked_endProfilerIfNeeded(_ mutableData: inout MutableData, fromTime: UInt64, toTime: UInt64)
        -> [EmbraceBacktrace]
    {
        guard mutableData.profiles.isEmpty else {
            return mutableData.backtraces.compactMap { backtrace in
                backtrace.timestamp >= fromTime && backtrace.timestamp < toTime ? backtrace : nil
            }
        }

        // remove all backtraces since we have no more
        defer { mutableData.backtraces.removeAll() }

        // end profiling
        mutableData.timer?.cancel()
        mutableData.timer = nil

        return mutableData.backtraces.compactMap { backtrace in
            backtrace.timestamp >= fromTime && backtrace.timestamp < toTime ? backtrace : nil
        }
    }

    public func beginProfile(name: String) -> EmbraceProfileIdentifier {

        // create a new profile
        let profile = EmbraceProfile_Internal(
            name: name,
            startTime: monotonicNanos()
        )

        // lock and add the profile and start profiler if needed
        data.withLock { [self] in
            $0.profiles[profile.id] = profile
            self.locked_beginProfilerIfNeeded(&$0)
        }

        return profile.id
    }

    public func endProfile(id: EmbraceProfileIdentifier) async -> EmbraceProfile? {
        await withCheckedContinuation { continuation in
            endProfile(id: id) { profile in
                continuation.resume(returning: profile)
            }
        }
    }

    public func endProfile(id: EmbraceProfileIdentifier, _ completion: @escaping (_ profile: EmbraceProfile?) -> Void) {

        // get the time
        let time = monotonicNanos()

        // lock and remove the profile
        // stop the profiler if needed
        // form and return a profile

        completionQueue.async { [self] in

            let result: EmbraceProfile?
            defer {
                DispatchQueue.global().async {
                    completion(result)
                }
            }

            struct InternalResultData {
                let profile: EmbraceProfile_Internal?
                let backtraces: [EmbraceBacktrace]
            }

            let prof = data.withLock { lock in
                guard let intProf = lock.profiles.removeValue(forKey: id) else {
                    return InternalResultData(profile: nil, backtraces: [])
                }
                return InternalResultData(
                    profile: intProf,
                    backtraces: locked_endProfilerIfNeeded(&lock, fromTime: intProf.startTime, toTime: time)
                )
            }

            guard let profile = prof.profile else {
                result = nil
                return
            }

            result = EmbraceProfile(
                id: profile.id,
                name: profile.name,
                backtraces: prof.backtraces,
                interval: interval,
                startTime: profile.startTime,
                endTime: time
            )
        }

    }
}

private func monotonicNanos() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
}

private struct EmbraceProfile_Internal {
    let id: EmbraceProfileIdentifier = UUID().uuidString
    let name: String
    let startTime: UInt64
}

extension EmbraceProfile_Internal: Equatable {
    static func == (lhs: EmbraceProfile_Internal, rhs: EmbraceProfile_Internal) -> Bool {
        lhs.id == rhs.id
    }
}
