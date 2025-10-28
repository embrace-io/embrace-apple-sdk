//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension LogType {
    public static let metricKitMetrics = LogType(system: "ios.metrickit-metrics")
}

extension LogSemantics {
    public struct MetricKitMetrics {
        public static let keyId = SemanticConventions.Log.recordUid.rawValue
        public static let keyProvider = "emb.provider"
        public static let keyPayload = "emb.payload"
        public static let keyPayLoadTimestamp = "emb.payload.timestamp"

        public static let metrickitProvider = "metrickit"
    }
}
