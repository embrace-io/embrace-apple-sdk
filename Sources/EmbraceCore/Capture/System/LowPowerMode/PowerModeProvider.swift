//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol PowerModeProvider {
    var isLowPowerModeEnabled: Bool { get }
}

@objc(EMBDefaultPowerModeProvider)
public class DefaultPowerModeProvider: NSObject, PowerModeProvider {
    @objc public var isLowPowerModeEnabled: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
}
