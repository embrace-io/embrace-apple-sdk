//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let threadBlockage = EmbraceType(primary: .performance, secondary: "thread_blockage")
}

extension SpanSemantics {
    public struct ThreadBlockage {
        public static let name = "emb-thread-blockage"
        public static let keyLastKnownTime = "last_known_time_unix_nano"
        public static let keyIntervalCode = "interval_code"
        public static let keyThreadPriority = "thread_priority"
    }
}
