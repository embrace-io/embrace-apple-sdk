//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let metricKitMetrics = EmbraceType(system: "ios.metrickit-metrics")
}

extension LogSemantics {
    /// Attribute keys and values for MetricKit metric logs.
    public struct MetricKitMetrics {
        public static let keyId = LogSemantics.Payload.keyId
        public static let keyProvider = LogSemantics.Payload.keyProvider
        public static let keyPayload = LogSemantics.Payload.keyPayload
        public static let keyPayLoadTimestamp = LogSemantics.Payload.keyPayLoadTimestamp

        public static let metrickitProvider = LogSemantics.Payload.metrickitProvider
    }
}
