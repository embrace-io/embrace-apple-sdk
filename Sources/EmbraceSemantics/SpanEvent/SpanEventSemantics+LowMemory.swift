//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let lowMemory = SpanEventType(system: "low_memory")
}

extension SpanEventSemantics {
    public struct LowMemory {
        public static let name = "emb-device-low-memory"
    }
}

extension SpanType {
    @available(
        *,
        deprecated,
        renamed: "SpanEventType.lowMemory",
        message: "Has been moved to `SpanEventType.lowMemory`"
    )
    public static let lowMemory = SpanType(system: "low_memory")
}
