//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol PowerModeProvider {
    var isLowPowerModeEnabled: Bool { get }
}

public final class DefaultPowerModeProvider: PowerModeProvider {
    public init() {}
    public var isLowPowerModeEnabled: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
}
