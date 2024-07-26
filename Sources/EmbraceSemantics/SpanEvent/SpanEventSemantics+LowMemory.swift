//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import EmbraceCommonInternal

public extension SpanType {
    static let lowMemory = SpanType(system: "low_memory")
}

public extension SpanEventSemantics {
    struct LowMemory {
        public static let name = "emb-device-low-memory"
    }
}
