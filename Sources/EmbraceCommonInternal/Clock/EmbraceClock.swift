//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A clock that works in nanoseconds
/// and contains the 3 basic times needed to
/// work with performance and interact with the outside world.
public struct EmbraceClock: Sendable {

    public typealias Nanoseconds = UInt64

    /// The clock for the current time.
    public static var current: EmbraceClock { EmbraceClock() }

    /// The clock for a ver far distant future.
    public static var never: EmbraceClock { EmbraceClock(0) }

    /// Uptime in nanoseconds, not incrementing during sleep.
    /// CLOCK_UPTIME_RAW
    public let uptime: Nanoseconds

    /// Monotonic time in nanoseconds, increments during sleep.
    /// using CLOCK_MONOTONIC_RAW.
    public let monotonic: Nanoseconds

    /// Walltime (real time, unix epoch) in nanoseconds.
    /// using CLOCK_REALTIME.
    public let realtime: Nanoseconds

    /// Private intializers
    private init() {
        // There will always be a very small skew,
        // but it's unimportant for our use case.
        self.init(
            uptime: clock_gettime_nsec_np(CLOCK_UPTIME_RAW),
            monotonic: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW),
            realtime: clock_gettime_nsec_np(CLOCK_REALTIME)
        )
    }

    private init(_ value: Nanoseconds) {
        self.uptime = value
        self.monotonic = value
        self.realtime = value
    }

    private init(uptime: Nanoseconds, monotonic: Nanoseconds, realtime: Nanoseconds) {
        self.uptime = uptime
        self.monotonic = monotonic
        self.realtime = realtime
    }
}

extension EmbraceClock {

    /// Substract one clock from another
    public static func - (lhs: EmbraceClock, rhs: EmbraceClock) -> EmbraceClock {
        return EmbraceClock(
            uptime: lhs.uptime &- rhs.uptime,
            monotonic: lhs.monotonic &- rhs.monotonic,
            realtime: lhs.realtime &- rhs.realtime
        )
    }

    /// Substract a duration from the clock.
    public static func - (lhs: EmbraceClock, rhs: Nanoseconds) -> EmbraceClock {
        return EmbraceClock(
            uptime: lhs.uptime &- rhs,
            monotonic: lhs.monotonic &- rhs,
            realtime: lhs.realtime &- rhs
        )
    }

    /// Add a duration from the clock.
    public static func + (lhs: EmbraceClock, rhs: Nanoseconds) -> EmbraceClock {
        return EmbraceClock(
            uptime: lhs.uptime &+ rhs,
            monotonic: lhs.monotonic &+ rhs,
            realtime: lhs.realtime &+ rhs
        )
    }
}

extension EmbraceClock {

    /// Get a `Date` from the clock.
    @inlinable
    public var date: Date {
        Date(timeIntervalSince1970: realtime.seconds)
    }
}

extension EmbraceClock.Nanoseconds {

    /// Convert nanoseconds to milliseconds
    @inlinable
    public var milliseconds: UInt64 {
        self / 1_000_000
    }

    /// Convert nanoseconds to seconds
    @inlinable
    public var seconds: Double {
        Double(self) / 1_000_000_000.0
    }
}
