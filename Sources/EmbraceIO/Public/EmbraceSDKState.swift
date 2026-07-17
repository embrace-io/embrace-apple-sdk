//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Enum used to represent the current state of the Embrace SDK
public enum EmbraceSDKState {
    /// The SDK was not started yet
    case notInitialized

    /// The SDK was started
    case started

    /// The SDK was stopped
    case stopped
}
