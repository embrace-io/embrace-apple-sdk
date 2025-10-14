//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanType {
    public static let hang = SpanType(performance: "thread_blockage")
}

extension SpanSemantics {
    public struct Hang {
        public static let name = "emb-thread-blockage"

        public static let keyLastKnownTimeUnixNano = "last_known_time_unix_nano"
        public static let keyIntervalCode = "interval_code"
        public static let keyThreadPriority = "thread_priority"
    }
}
