//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let hang = SpanEventType(performance: "thread_blockage_sample")
}

extension SpanEventSemantics {
    public struct Hang {
        public static let name = "thread_blockage_sample"

        public static let keySampleOverhead = "sample_overhead"
        public static let keyFrameCount = "frame_count"
    }
}
