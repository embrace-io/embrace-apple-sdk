//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// Defines all possible statuses for spans.
@objc public enum EmbraceSpanStatus: Int {
    case ok
    case unset
    case error

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
