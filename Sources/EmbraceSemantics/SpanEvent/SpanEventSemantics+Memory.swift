//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let lowMemory = SpanEventType(system: "low_memory")
    public static let memoryPressure = SpanEventType(system: "memory_pressure")
    public static let memoryLevel = SpanEventType(system: "memory_level")
}

extension SpanEventSemantics {
    public struct LowMemory {
        public static let name = "emb-device-low-memory"
    }

    public struct MemoryPressure {
        public static let name = "emb-memory-pressure"
    }

    public struct MemoryLevel {
        public static let name = "emb-memory-level"
    }
}

extension SpanEventSemantics {

    public struct Memory {
        public static let level = "emb.memory_level"
        public static let pressure = "emb.memory_pressure"
        public static let footprint = "emb.memory_footprint"
        public static let limit = "emb.memory_limit"
        public static let remaining = "emb.memory_remaining"
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
