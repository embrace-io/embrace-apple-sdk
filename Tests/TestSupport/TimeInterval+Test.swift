//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension TimeInterval {
    static var shortTimeout: TimeInterval {
        return 0.1
    }

    static var defaultTimeout: TimeInterval {
        return 1
    }

    static var longTimeout: TimeInterval {
        return 3
    }

    static var veryLongTimeout: TimeInterval {
        return 5
    }
}
