//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Embrace specific error status for spans
public enum EmbraceSpanErrorCode: Int {
    /// Span ended in an expected, but less than optimal state
    case failure = 1

    /// Span ended because user reverted intent
    case userAbandon = 2

    /// Span ended in some other way
    case unknown = 3

    /// The serialized string value of the error code (e.g. `"failure"`, `"user_abandon"`, `"unknown"`).
    public var name: String {
        switch self {
        case .failure: "failure"
        case .userAbandon: "user_abandon"
        case .unknown: "unknown"
        }
    }

    /// Creates an `EmbraceSpanErrorCode` from its serialized `name`, or `nil` if the name is unrecognized.
    public init?(name: String) {
        switch name {
        case "failure": self = .failure
        case "user_abandon": self = .userAbandon
        case "unknown": self = .unknown
        default: return nil
        }
    }
}
