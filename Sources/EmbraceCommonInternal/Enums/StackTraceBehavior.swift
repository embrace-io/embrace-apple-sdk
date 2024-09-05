//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Describes the behavior for automatically capturing stack traces.
public enum StackTraceBehavior: Int {
    /// Stack traces are not automatically captured.
    case notIncluded

    /// The default behavior for automatically capturing stack traces.
    case `default`
}
