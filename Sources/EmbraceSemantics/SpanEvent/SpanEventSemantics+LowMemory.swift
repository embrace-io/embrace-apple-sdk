//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let lowMemory = EmbraceType(system: "low_memory")
}

extension SpanEventSemantics {
    /// Attribute keys and values for low memory warning span events.
    public struct LowMemory {
        public static let name = "emb-device-low-memory"
    }
}
