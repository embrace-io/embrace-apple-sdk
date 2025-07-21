//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension EmbraceConfig {
    public class Options {
        let minimumUpdateInterval: TimeInterval

        public init(
            minimumUpdateInterval: TimeInterval = 60 * 60
        ) {
            self.minimumUpdateInterval = minimumUpdateInterval
        }
    }
}
