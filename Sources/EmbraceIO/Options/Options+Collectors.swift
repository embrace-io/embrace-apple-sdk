//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon

public extension Array where Element == any Collector {
    static var automatic: [any Collector] {
        return CollectorFactory.platformCollectors
    }
}
