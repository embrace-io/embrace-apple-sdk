//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// `ExperimentsLimits` manages the bounds applied to the experiments and feature flags tracked
/// through the SDK.
///
/// The encoded value these limits protect is exempt from the standard attribute value length limit.
/// Rather than capping the encoded string, the inputs are bounded: how many records a process may
/// hold, and how long each identifier and variant may be.
@objc public final class ExperimentsLimits: NSObject {

    // MARK: - Defaults

    /// Default maximum number of records (experiments plus feature flags) held during a process.
    public static let defaultMaxCount = 500
    /// Default maximum length of an experiment or feature flag identifier.
    public static let defaultMaxIdLength = 128
    /// Default maximum length of a variant.
    public static let defaultMaxVariantLength = 128

    // MARK: - Bounds
    //
    // Ceilings for the remote-config-driven values. A remote config may raise or lower each limit,
    // but never past these, so a bad or hostile remote value cannot drive unbounded memory use or an
    // unbounded payload. Clamping in `init` means every consumer of `ExperimentsLimits` inherits the
    // guarantee.

    /// Highest value `maxCount` may be set to remotely.
    public static let maxSettableCount = 5000
    /// Highest value `maxIdLength` may be set to remotely.
    public static let maxSettableIdLength = 1024
    /// Highest value `maxVariantLength` may be set to remotely.
    public static let maxSettableVariantLength = 1024

    // MARK: - Values

    /// Maximum number of records held during a process, covering active and ended records alike.
    /// Clamped to ``maxSettableCount``.
    public let maxCount: Int

    /// Maximum length of an identifier. An identifier longer than this drops the whole entry; it is
    /// never truncated, as a truncated identifier would refer to a different record.
    /// Clamped to ``maxSettableIdLength``.
    public let maxIdLength: Int

    /// Maximum length of a variant. A variant longer than this drops the whole entry.
    /// Clamped to ``maxSettableVariantLength``.
    public let maxVariantLength: Int

    public init(
        maxCount: Int = ExperimentsLimits.defaultMaxCount,
        maxIdLength: Int = ExperimentsLimits.defaultMaxIdLength,
        maxVariantLength: Int = ExperimentsLimits.defaultMaxVariantLength
    ) {
        self.maxCount = ExperimentsLimits.clamped(
            maxCount,
            fallback: ExperimentsLimits.defaultMaxCount,
            max: ExperimentsLimits.maxSettableCount
        )
        self.maxIdLength = ExperimentsLimits.clamped(
            maxIdLength,
            fallback: ExperimentsLimits.defaultMaxIdLength,
            max: ExperimentsLimits.maxSettableIdLength
        )
        self.maxVariantLength = ExperimentsLimits.clamped(
            maxVariantLength,
            fallback: ExperimentsLimits.defaultMaxVariantLength,
            max: ExperimentsLimits.maxSettableVariantLength
        )
    }

    /// A value of zero or more is capped at `maximum`; zero is a valid way to turn tracking off.
    /// A negative value is not a smaller limit but a malformed one, so it falls back to `fallback`
    /// rather than silently disabling the feature.
    private static func clamped(_ value: Int, fallback: Int, max maximum: Int) -> Int {
        guard value >= 0 else { return fallback }
        return Swift.min(value, maximum)
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(maxCount)
        hasher.combine(maxIdLength)
        hasher.combine(maxVariantLength)
        return hasher.finalize()
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Self else {
            return false
        }
        return maxCount == other.maxCount
            && maxIdLength == other.maxIdLength
            && maxVariantLength == other.maxVariantLength
    }
}
