//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension SpanEventSemantics {
    /// Attribute keys and values for hang span events.
    public struct Hang {
        public static let name = "thread_blockage_sample"

        public static let keySampleOverhead = "sample_overhead"
        public static let keyFrameCount = "frame_count"
    }
}
