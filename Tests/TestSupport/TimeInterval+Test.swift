//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension TimeInterval {
    public static var veryShortTimeout: TimeInterval {
        return 0.1
    }

    public static var shortTimeout: TimeInterval {
        return 0.5
    }

    public static var defaultTimeout: TimeInterval {
        return 3
    }

    public static var longTimeout: TimeInterval {
        return 5
    }

    public static var veryLongTimeout: TimeInterval {
        return 7
    }
}
