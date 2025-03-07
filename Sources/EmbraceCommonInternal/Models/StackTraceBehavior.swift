//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Describes the behavior for automatically capturing stack traces.
public enum StackTraceBehavior {
    /// Stack traces are not automatically captured.
    case notIncluded

    /// The default behavior for automatically capturing stack traces.
    case `default`

    /// A custom stack trace provided.
    case custom(_ value: EmbraceStackTrace)
}

extension StackTraceBehavior: Equatable {
    public static func == (lhs: StackTraceBehavior, rhs: StackTraceBehavior) -> Bool {
        switch (lhs, rhs) {
        case (.notIncluded, .notIncluded), (.default, .default):
            return true
        case let (.custom(lhsValue), .custom(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
