//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension LogSemantics {
    /// Attribute keys and values shared by every log that carries a serialized diagnostic
    /// payload produced by an external reporter (crashes, hangs and MetricKit metrics).
    ///
    /// The per-signal namespaces (`Crash`, `Hang`, `MetricKitMetrics`) expose these keys under
    /// their own names, but this struct holds the single source of truth for the actual values.
    public struct Payload {
        /// Unique identifier of the log record carrying the payload.
        public static let keyId = LogSemantics.keyId

        /// Name of the reporter that produced the payload.
        public static let keyProvider = "emb.provider"

        /// The serialized payload itself.
        public static let keyPayload = "emb.payload"

        /// Time at which the payload was generated, in nanoseconds since epoch.
        public static let keyPayLoadTimestamp = "emb.payload.timestamp"

        /// Value for `keyProvider` when the payload comes from MetricKit.
        public static let metrickitProvider = "metrickit"

        /// Value for `keyProvider` when the payload comes from KSCrash.
        public static let ksCrashProvider = "kscrash"
    }
}
