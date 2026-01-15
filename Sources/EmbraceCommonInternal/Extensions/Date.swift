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

    #if os(watchOS)
        public var millisecondsSince1970Truncated: Int64 {
            Int64(trunc(self.millisecondsSince1970))
        }
        public var nanosecondsSince1970Truncated: Int64 {
            Int64(trunc(self.nanosecondsSince1970))
        }
        public var serializedInterval: Int64 {
            Int64(millisecondsSince1970.rounded(.down))
        }
        init(_ millisSince1970: Int64) {
            self.init(Double(millisSince1970))
        }
    #else
        public var millisecondsSince1970Truncated: Int {
            Int(trunc(self.millisecondsSince1970))
        }

        public var nanosecondsSince1970Truncated: Int {
            Int(trunc(self.nanosecondsSince1970))
        }

        public var serializedInterval: Int {
            Int(millisecondsSince1970.rounded(.down))
        }

        init(_ millisSince1970: Int) {
            self.init(Double(millisSince1970))
        }
    #endif
}
