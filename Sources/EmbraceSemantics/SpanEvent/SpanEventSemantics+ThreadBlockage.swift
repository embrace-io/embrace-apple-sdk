//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension SpanEventSemantics {
    public struct ThreadBlockage {
        public static let name = "perf.thread_blockage_sample"
        public static let keySampleOverhead = "sample_overhead"
        public static let keyFrameCount = "frame_count"
        public static let keyStacktrace = "stacktrace"
    }
}
