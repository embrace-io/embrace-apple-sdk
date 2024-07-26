//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanType {
    static let lowPower = SpanType(system: "low_power")
}

public extension SpanSemantics {
    struct LowPower {
        public static let name = "emb-device-low-power"
        public static let keyStartReason = "start_reason"
        public static let systemQuery = "system_query"
        public static let systemNotification = "system_notification"
    }
}
