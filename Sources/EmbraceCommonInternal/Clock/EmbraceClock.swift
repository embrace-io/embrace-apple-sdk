//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - EmbraceClock

/// A high-resolution clock abstraction that captures three core time domains:
/// - **Uptime:** Time since boot, excluding sleep (`CLOCK_UPTIME_RAW`)
/// - **Monotonic:** Time since boot, including sleep (`CLOCK_MONOTONIC_RAW`)
/// - **Realtime:** Wall time since the Unix epoch (`CLOCK_REALTIME`)
///
/// `EmbraceClock` is used for performance measurement, event correlation,
/// and mapping between system-relative and wall-clock times.
///
/// - Example: Capture a timestamp snapshot and convert to `Date`
/// ```swift
/// let clock = EmbraceClock.current
/// print("Wall Date:", clock.date)          // From `realtime`
/// print("Uptime ns:", clock.uptime.nanosecondsValue)
/// print("Monotonic ns:", clock.monotonic.nanosecondsValue)
/// ```
///
/// - Example: Latency measurement with monotonic time
/// ```swift
/// let start = EmbraceClock.current
/// performWork()
/// let end = EmbraceClock.current
/// let delta = end - start
/// let elapsedNs = delta.monotonic.nanosecondsValue
/// ```
public struct EmbraceClock: Sendable {

    // MARK: - Instant

    /// Represents a single timestamp with unit flexibility (`seconds`, `milliseconds`, or `nanoseconds`).
    ///
    /// Provides safe arithmetic, unit conversion, and value accessors across time scales.
    ///
    /// - Note:
    ///   Use `nanosecondsValue`/`millisecondsValue`/`secondsValue` when you need a concrete numeric value.
    public struct Instant: Sendable {

        /// The time unit used to represent an `Instant`.
        public enum Unit: Sendable {
            /// A value expressed in seconds.
            case seconds(Double)
            /// A value expressed in milliseconds.
            case milliseconds(UInt64)
            /// A value expressed in nanoseconds.
            case nanoseconds(UInt64)
        }

        /// The underlying representation of this instant.
        public let unit: Unit

        // MARK: - Initialization

        /// Creates a new instant in seconds.
        ///
        /// - Example:
        /// ```swift
        /// let t = EmbraceClock.Instant(seconds: 1.25)
        /// print(t.nanosecondsValue) // 1_250_000_000
        /// ```
        public init(seconds value: Double) {
            self.unit = .seconds(value)
        }

        /// Creates a new instant in milliseconds.
        ///
        /// - Example:
        /// ```swift
        /// let t = EmbraceClock.Instant(milliseconds: 250)
        /// print(t.secondsValue) // 0.25
        /// ```
        public init(milliseconds value: UInt64) {
            self.unit = .milliseconds(value)
        }

        /// Creates a new instant in nanoseconds.
        ///
        /// - Example:
        /// ```swift
        /// let t = EmbraceClock.Instant(nanoseconds: 5_000_000)
        /// print(t.millisecondsValue) // 5
        /// ```
        public init(nanoseconds value: UInt64) {
            self.unit = .nanoseconds(value)
        }

        // MARK: - Factory Methods

        /// Creates an instant from a value in seconds.
        ///
        /// - Example:
        /// ```swift
        /// let s = EmbraceClock.Instant.seconds(2.5)
        /// ```
        public static func seconds(_ value: Double) -> Instant {
            Instant(seconds: value)
        }

        /// Creates an instant from a value in milliseconds.
        ///
        /// - Example:
        /// ```swift
        /// let ms = EmbraceClock.Instant.milliseconds(1500)
        /// print(ms.secondsValue) // 1.5
        /// ```
        public static func milliseconds(_ value: UInt64) -> Instant {
            Instant(milliseconds: value)
        }

        /// Creates an instant from a value in nanoseconds.
        ///
        /// - Example:
        /// ```swift
        /// let ns = EmbraceClock.Instant.nanoseconds(750_000)
        /// print(ns.millisecondsValue) // 0
        /// ```
        public static func nanoseconds(_ value: UInt64) -> Instant {
            Instant(nanoseconds: value)
        }

        // MARK: - Arithmetic Operators

        /// Subtracts one instant from another using standard integer subtraction.
        ///
        /// - Important: Uses **saturating integer semantics** of `UInt64` when accessing `nanosecondsValue`
        ///   before conversion. Prefer `&-` if you explicitly want wrapping behavior.
        ///
        /// - Example:
        /// ```swift
        /// let a = EmbraceClock.Instant.milliseconds(1200)
        /// let b = EmbraceClock.Instant.milliseconds(200)
        /// let c = a - b
        /// print(c.millisecondsValue) // 1000
        /// ```
        public static func - (lhs: Instant, rhs: Instant) -> Instant {
            .nanoseconds(lhs.nanosecondsValue - rhs.nanosecondsValue)
        }

        /// Subtracts one instant from another using wrapping subtraction (`&-`).
        ///
        /// - Example:
        /// ```swift
        /// let a = EmbraceClock.Instant.nanoseconds(10)
        /// let b = EmbraceClock.Instant.nanoseconds(20)
        /// let wrap = a &- b
        /// // `wrap` will wrap around UInt64
        /// ```
        public static func &- (lhs: Instant, rhs: Instant) -> Instant {
            .nanoseconds(lhs.nanosecondsValue &- rhs.nanosecondsValue)
        }

        /// Adds two instants using standard integer addition.
        ///
        /// - Example:
        /// ```swift
        /// let a = EmbraceClock.Instant.seconds(1)
        /// let b = EmbraceClock.Instant.milliseconds(250)
        /// print((a + b).secondsValue) // 1.25
        /// ```
        public static func + (lhs: Instant, rhs: Instant) -> Instant {
            .nanoseconds(lhs.nanosecondsValue + rhs.nanosecondsValue)
        }

        /// Adds two instants using wrapping addition (`&+`).
        ///
        /// - Example:
        /// ```swift
        /// let big = EmbraceClock.Instant.nanoseconds(.max)
        /// let one = EmbraceClock.Instant.nanoseconds(1)
        /// let wrap = big &+ one // wraps UInt64
        /// ```
        public static func &+ (lhs: Instant, rhs: Instant) -> Instant {
            .nanoseconds(lhs.nanosecondsValue &+ rhs.nanosecondsValue)
        }

        // MARK: - Unit Conversion

        /// Returns this instant expressed in seconds.
        ///
        /// - Example:
        /// ```swift
        /// let ns = EmbraceClock.Instant.nanoseconds(2_000_000_000)
        /// print(ns.seconds().secondsValue) // 2.0
        /// ```
        public func seconds() -> Instant {
            switch unit {
            case .seconds:
                return self
            case .milliseconds(let value):
                return .seconds(Double(value) / 1_000.0)
            case .nanoseconds(let value):
                return .seconds(Double(value) / 1_000_000_000.0)
            }
        }

        /// Returns this instant expressed in milliseconds.
        ///
        /// - Example:
        /// ```swift
        /// let s = EmbraceClock.Instant.seconds(0.75)
        /// print(s.milliseconds().millisecondsValue) // 750
        /// ```
        public func milliseconds() -> Instant {
            switch unit {
            case .seconds(let value):
                return .milliseconds(UInt64(value * 1_000.0))
            case .milliseconds:
                return self
            case .nanoseconds(let value):
                return .milliseconds(value / 1_000_000)
            }
        }

        /// Returns this instant expressed in nanoseconds.
        ///
        /// - Example:
        /// ```swift
        /// let ms = EmbraceClock.Instant.milliseconds(3)
        /// print(ms.nanoseconds().nanosecondsValue) // 3_000_000
        /// ```
        public func nanoseconds() -> Instant {
            switch unit {
            case .seconds(let value):
                return .nanoseconds(UInt64(value * 1_000_000_000.0))
            case .milliseconds(let value):
                return .nanoseconds(value * 1_000_000)
            case .nanoseconds:
                return self
            }
        }

        // MARK: - Value Accessors

        /// Returns the numeric value of the instant in seconds.
        ///
        /// - Example:
        /// ```swift
        /// let t = EmbraceClock.Instant.milliseconds(1500)
        /// print(t.secondsValue) // 1.5
        /// ```
        public var secondsValue: Double {
            switch unit {
            case .seconds(let value):
                return value
            case .milliseconds(let value):
                return Double(value) / 1_000.0
            case .nanoseconds(let value):
                return Double(value) / 1_000_000_000.0
            }
        }

        /// Returns the numeric value of the instant in milliseconds.
        ///
        /// - Example:
        /// ```swift
        /// let t = EmbraceClock.Instant.seconds(2.0)
        /// print(t.millisecondsValue) // 2000
        /// ```
        public var millisecondsValue: UInt64 {
            switch unit {
            case .seconds(let value):
                return UInt64(value * 1_000.0)
            case .milliseconds(let value):
                return value
            case .nanoseconds(let value):
                return value / 1_000_000
            }
        }

        /// Returns the numeric value of the instant in nanoseconds.
        ///
        /// - Example:
        /// ```swift
        /// let t = EmbraceClock.Instant.milliseconds(3)
        /// print(t.nanosecondsValue) // 3_000_000
        /// ```
        public var nanosecondsValue: UInt64 {
            switch unit {
            case .seconds(let value):
                return UInt64(value * 1_000_000_000.0)
            case .milliseconds(let value):
                return value * 1_000_000
            case .nanoseconds(let value):
                return value
            }
        }
    }

    // MARK: - Preset Clocks

    /// Returns a snapshot of the current system clock across uptime, monotonic, and realtime domains.
    ///
    /// - Example:
    /// ```swift
    /// let snapshot = EmbraceClock.current
    /// print(snapshot.realtime.secondsValue) // seconds since 1970
    /// ```
    public static var current: EmbraceClock { EmbraceClock() }

    /// Returns a clock set to an infinitely distant future value (used as a sentinel).
    ///
    /// - Example:
    /// ```swift
    /// let deadline = EmbraceClock.never
    /// // Useful as a "no deadline" / "disabled" marker.
    /// ```
    public static let never: EmbraceClock = { EmbraceClock(.nanoseconds(.max)) }()

    // MARK: - Clock Components

    /// Uptime in nanoseconds (does **not** advance during system sleep).
    /// Backed by `CLOCK_UPTIME_RAW`.
    public let uptime: Instant

    /// Monotonic time in nanoseconds (advances during system sleep).
    /// Backed by `CLOCK_MONOTONIC_RAW`.
    public let monotonic: Instant

    /// Wall-clock time in nanoseconds since the Unix epoch.
    /// Backed by `CLOCK_REALTIME`.
    public let realtime: Instant

    // MARK: - Initialization

    /// Creates a new clock snapshot capturing the three time sources (`uptime`, `monotonic`, and `realtime`).
    ///
    /// The timestamps are sampled individually, so a small skew is expected but insignificant for
    /// most measurement or correlation use cases.
    ///
    /// - Example:
    /// ```swift
    /// let c = EmbraceClock.current
    /// ```
    private init() {
        self.init(
            uptime: .nanoseconds(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)),
            monotonic: .nanoseconds(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)),
            realtime: .nanoseconds(clock_gettime_nsec_np(CLOCK_REALTIME))
        )
    }

    /// Creates a clock using a single `Instant` for all time sources.
    ///
    /// - Example:
    /// ```swift
    /// let zero = EmbraceClock(EmbraceClock.Instant.nanoseconds(0)) // private ctor
    /// ```
    private init(_ value: Instant) {
        self.uptime = value
        self.monotonic = value
        self.realtime = value
    }

    /// Creates a clock from explicit time sources.
    ///
    /// - Example:
    /// ```swift
    /// let c = EmbraceClock(
    ///     uptime: .nanoseconds(1),
    ///     monotonic: .nanoseconds(2),
    ///     realtime: .nanoseconds(3)
    /// )
    /// ```
    private init(uptime: Instant, monotonic: Instant, realtime: Instant) {
        self.uptime = uptime
        self.monotonic = monotonic
        self.realtime = realtime
    }
}

// MARK: - Arithmetic

extension EmbraceClock {

    /// Subtracts one clock snapshot from another.
    ///
    /// Each component (`uptime`, `monotonic`, `realtime`) is subtracted independently using wrapping subtraction.
    ///
    /// - Example:
    /// ```swift
    /// let start = EmbraceClock.current
    /// work()
    /// let end = EmbraceClock.current
    /// let diff = end - start
    /// print(diff.monotonic.nanosecondsValue)
    /// ```
    public static func - (lhs: EmbraceClock, rhs: EmbraceClock) -> EmbraceClock {
        EmbraceClock(
            uptime: .nanoseconds(lhs.uptime.nanosecondsValue &- rhs.uptime.nanosecondsValue),
            monotonic: .nanoseconds(lhs.monotonic.nanosecondsValue &- rhs.monotonic.nanosecondsValue),
            realtime: .nanoseconds(lhs.realtime.nanosecondsValue &- rhs.realtime.nanosecondsValue)
        )
    }
}

// MARK: - Date Conversion

extension EmbraceClock {

    /// Converts the `realtime` value to a `Date` instance.
    ///
    /// This enables easy interoperability with standard Foundation APIs.
    ///
    /// - Example:
    /// ```swift
    /// let now = EmbraceClock.current
    /// let date = now.date
    /// formatter.string(from: date)
    /// ```
    @inlinable
    public var date: Date {
        Date(timeIntervalSince1970: realtime.secondsValue)
    }
}
