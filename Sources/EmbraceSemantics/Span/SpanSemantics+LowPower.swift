//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let lowPower = EmbraceType(system: "low_power")
}

extension SpanSemantics {
    public struct LowPower {
        public static let name = "emb-device-low-power"
        public static let keyStartReason = "start_reason"
        public static let systemQuery = "system_query"
        public static let systemNotification = "system_notification"
    }
}
