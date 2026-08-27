//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Provides the device's current Low Power Mode state.
public protocol PowerModeProvider {
    /// Whether the device currently has Low Power Mode enabled.
    var isLowPowerModeEnabled: Bool { get }
}

/// Default `PowerModeProvider` backed by `ProcessInfo.isLowPowerModeEnabled`.
public final class DefaultPowerModeProvider: PowerModeProvider {
    /// Creates a new `DefaultPowerModeProvider`.
    public init() {}

    /// Whether the device currently has Low Power Mode enabled.
    public var isLowPowerModeEnabled: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
}
