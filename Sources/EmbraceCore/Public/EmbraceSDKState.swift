//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Enum used to represent the current state of the Embrace SDK
@objc public enum EmbraceSDKState: Int {
    /// The SDK was not setup yet
    case notInitialized

    /// The SDK was setup but hasn't started yet
    case initialized

    /// The SDK was started
    case started

    /// The SDK was stopped
    case stopped
}
