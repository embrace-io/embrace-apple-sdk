//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let smoothness = EmbraceType(performance: "smoothness")
}

extension SpanSemantics {
    /// Attribute keys for smoothness spans. Matches Android's `emb.smoothness` semconv.
    public struct Smoothness {
        public static let name = "smoothness"

        /// Frames rendered while the span was open.
        public static let keyFrameCount = "smoothness.frame_count"

        /// Total late time while the span was open, in 60fps reference frames.
        public static let keyNormalizedDroppedFrames = "smoothness.normalized_dropped_frames"
    }
}
