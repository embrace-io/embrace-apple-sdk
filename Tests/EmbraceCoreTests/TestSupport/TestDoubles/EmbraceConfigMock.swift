//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceConfigInternal
import TestSupport
import Foundation

class EmbraceConfigMock {
    static func `default`(sdkEnabled: Bool = true) -> EmbraceConfig {
        EmbraceConfig(
            configurable: MockEmbraceConfigurable(isSDKEnabled: sdkEnabled),
            options: .init(minimumUpdateInterval: .infinity),
            notificationCenter: .default,
            logger: MockLogger(),
            queue: DispatchQueue.main
        )
    }
}
