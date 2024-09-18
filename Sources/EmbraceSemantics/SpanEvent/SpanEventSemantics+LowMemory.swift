//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import EmbraceCommonInternal

public extension SpanEventType {
    static let lowMemory = SpanEventType(system: "low_memory")
}

public extension SpanEventSemantics {
    struct LowMemory {
        public static let name = "emb-device-low-memory"
    }
}
