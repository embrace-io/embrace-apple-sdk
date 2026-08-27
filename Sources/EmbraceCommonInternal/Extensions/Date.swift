//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension Date {
    public var millisecondsSince1970: Double {
        Double(self.timeIntervalSince1970 * 1000)
    }

    public var nanosecondsSince1970: Double {
        self.timeIntervalSince1970 * Double(NSEC_PER_SEC)
    }

    public var millisecondsSince1970Truncated: EMBInt {
        EMBInt(trunc(self.millisecondsSince1970))
    }

    public var nanosecondsSince1970Truncated: EMBInt {
        EMBInt(trunc(self.nanosecondsSince1970))
    }

    public var serializedInterval: EMBInt {
        EMBInt(millisecondsSince1970.rounded(.down))
    }

    /// Largest distance from the 1970 epoch, in seconds, that every timestamp conversion in the SDK can
    /// represent. `Int64` nanoseconds run out at 9223372036.854775807 seconds, and this stays under that
    /// boundary on both sides of the epoch.
    private static let maxTimestampInterval: TimeInterval = 9_223_372_036

    /// Whether this date can be converted to a timestamp without crashing.
    ///
    /// A `Date` stores a `Double`, so it can hold values that no integer timestamp can express: `NaN`,
    /// `+infinity`, `-infinity`, and magnitudes far larger than any real calendar date. All of them are
    /// created without error and compare, format and persist like ordinary dates. They only fail when
    /// converted to an integer number of milliseconds or nanoseconds, and that failure is a fatal error
    /// rather than something a caller can recover from.
    ///
    /// A valid date is finite and no further from the 1970 epoch than `Int64` nanoseconds can express,
    /// which covers 1677-09-21 through 2262-04-11. That is the strictest of the conversions performed by
    /// the SDK, and far wider than any date a device clock can plausibly report.
    ///
    /// Check this on every date that comes from outside the SDK before it reaches a conversion.
    public var isValid: Bool {
        // `NaN` and both infinities fail this comparison as well: every comparison against `NaN` is
        // false, and infinity exceeds any bound.
        abs(timeIntervalSince1970) <= Self.maxTimestampInterval
    }

}
