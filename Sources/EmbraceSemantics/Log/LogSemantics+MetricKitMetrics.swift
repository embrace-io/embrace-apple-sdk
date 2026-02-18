//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let metricKitMetrics = EmbraceType(system: "ios.metrickit-metrics")
}

extension LogSemantics {
    public struct MetricKitMetrics {
        public static let keyId = "log.record.uid"
        public static let keyProvider = "emb.provider"
        public static let keyPayload = "emb.payload"
        public static let keyPayLoadTimestamp = "emb.payload.timestamp"

        public static let metrickitProvider = "metrickit"
    }
}
