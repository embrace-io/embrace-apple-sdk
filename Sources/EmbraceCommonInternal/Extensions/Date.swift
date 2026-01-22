//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Date {
    public var millisecondsSince1970: Double {
        Double(self.timeIntervalSince1970 * 1000)
    }

    public var nanosecondsSince1970: Double {
        self.timeIntervalSince1970 * Double(NSEC_PER_SEC)
    }

    init(_ millisSince1970: Double) {
        let interval = millisSince1970 / 1000
        self.init(timeIntervalSince1970: interval)
    }

    public var millisecondsSince1970Truncated: EMBInt {
        EMBInt(trunc(self.millisecondsSince1970))
    }
    
    public var nanosecondsSince1970Truncated: EMBInt {
        EMBInt(trunc(self.nanosecondsSince1970))
    }
    
    public var serializedInterval: EMBInt {
        EMBInt(millisecondsSince1970.rounded(.down))
    }
    
    init(_ millisSince1970: EMBInt) {
        self.init(Double(millisSince1970))
    }
    
}
