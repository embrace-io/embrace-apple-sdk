//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

public extension SpanEventType {
    static let lowMemory = SpanEventType(system: "low_memory")
}

public extension SpanEventSemantics {
    struct LowMemory {
        public static let name = "emb-device-low-memory"
    }
}

public extension SpanType {
    @available(
        *,
         deprecated,
         renamed: "SpanEventType.lowMemory",
         message: "Has been moved to `SpanEventType.lowMemory`")
    static let lowMemory = SpanType(system: "low_memory")
}
