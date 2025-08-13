//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Wrapper around UUID used for all Embrace signals.
public struct EmbraceIdentifier: Equatable {
    let value: UUID?
    public let stringValue: String

    /// Creates an `EmbraceIdentifier` for the given `UUID`.
    public init(value: UUID) {
        self.value = value
        self.stringValue = value.withoutHyphen
    }

    /// Creates an `EmbraceIdentifier` for the given UUID string without hyphens.
    /// If the string format is not correct, `value` will be nil.
    public init(stringValue: String) {
        self.value = UUID(withoutHyphen: stringValue)
        self.stringValue = stringValue
    }

    static public func == (lhs: EmbraceIdentifier, rhs: EmbraceIdentifier) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}

// MARK: Random
extension EmbraceIdentifier {
    public static var random: EmbraceIdentifier {
        .init(value: UUID())
    }
}

// MARK: Current Process Identifier
public struct ProcessIdentifier {
    public static let current: EmbraceIdentifier = .random
}

// MARK: Int Value
extension EmbraceIdentifier {
    /// Returns the integer value of the device identifier using the number of digits from the suffix
    /// - Parameters:
    ///   - digitCount: The number of digits to use for the deviceId calculation
    public func intValue(digitCount: UInt) -> UInt64 {
        var deviceIdHexValue: UInt64 = UInt64.max  // defaults to everything disabled

        let hexValue = stringValue
        if hexValue.count >= digitCount {
            deviceIdHexValue = UInt64.init(hexValue.suffix(Int(digitCount)), radix: 16) ?? .max
        }

        return deviceIdHexValue
    }
}

// MARK: CustomStringConvertible
extension EmbraceIdentifier: CustomStringConvertible {
    public var description: String { value?.uuidString ?? stringValue }
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
