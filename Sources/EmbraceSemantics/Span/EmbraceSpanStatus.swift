//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// Defines all possible statuses for spans.
public enum EmbraceSpanStatus: EMBInt {
    case ok
    case unset
    case error

    /// The serialized string value of the status (e.g. `"ok"`, `"unset"`, `"error"`).
    public var name: String {
        switch self {
        case .ok:
            return "ok"
        case .unset:
            return "unset"
        case .error:
            return "error"
        }
    }
}
