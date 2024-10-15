//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

public extension EmbraceConfig {
    class Options {
        let minimumUpdateInterval: TimeInterval

        public init(
            minimumUpdateInterval: TimeInterval = 60 * 60
        ) {
            self.minimumUpdateInterval = minimumUpdateInterval
        }
    }
}
