//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    /// Used for crash reports provided by the Crash Reporter
    public static let crash = EmbraceType(system: "ios.crash")
}

extension LogSemantics {
    /// Attribute keys and values for crash logs.
    public struct Crash {
        public static let keyId = "log.record.uid"
        public static let keyProvider = "emb.provider"
        public static let keyPayload = "emb.payload"

        public static let ksCrashProvider = "kscrash"
        public static let metrickitProvider = "metrickit"
    }
}
