//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Wrapper around UUID used for all Embrace signals.
public class EmbraceIdentifier: Equatable {
    /// The identifier's underlying string value.
    public let stringValue: String

    /// Creates an `EmbraceIdentifier` for the given `UUID`.
    public init(value: UUID) {
        self.stringValue = value.withoutHyphen
    }

    /// Creates an `EmbraceIdentifier` for the given string.
    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    static public func == (lhs: EmbraceIdentifier, rhs: EmbraceIdentifier) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}

// MARK: Random
extension EmbraceIdentifier {
    /// Returns a new `EmbraceIdentifier` backed by a random `UUID`.
    public static var random: EmbraceIdentifier {
        .init(value: UUID())
    }
}

// MARK: Current Process Identifier
/// Holds the identifier that uniquely identifies the current process run.
public struct ProcessIdentifier {
    /// The identifier generated for the current process. Stable for the lifetime of the process.
    public static let current: EmbraceIdentifier = .random
}

// MARK: Int Value
extension EmbraceIdentifier {
    /// Returns the integer value of the identifier using the given number of hexadecimal digits from the suffix.
    /// - Parameter digitCount: The number of hexadecimal digits from the end of the identifier to use for the calculation.
    /// - Returns: The integer value parsed from the identifier's hex suffix, or `UInt64.max` if it can't be parsed.
    public func intValue(digitCount: UInt) -> UInt64 {
        var deviceIdHexValue: UInt64 = UInt64.max  // defaults to everything disabled

        let hexValue = stringValue
        if hexValue.count >= digitCount {
            deviceIdHexValue = UInt64.init(hexValue.suffix(Int(digitCount)), radix: 16) ?? .max
        }

        return deviceIdHexValue
    }
}

// MARK: UUID
extension UUID {
    /// Initialize a UUID from a string that is 32 hexadecimal characters without hyphens
    /// Will defensively attempt to initialize UUID if string contains hyphens
    public init?(withoutHyphen: String) {
        if withoutHyphen.count != 32 {
            // try to initialize with hyphens
            self.init(uuidString: withoutHyphen)
            return
        }

        let uuidString = withoutHyphen.replacingOccurrences(
            of: "(.{8})(.{4})(.{4})(.{4})(.{12})",
            with: "$1-$2-$3-$4-$5",
            options: .regularExpression
        )
        self.init(uuidString: uuidString)
    }

    /// A UUID string without hyphens
    public var withoutHyphen: String {
        return uuidString.replacingOccurrences(of: "-", with: "")
    }
}
