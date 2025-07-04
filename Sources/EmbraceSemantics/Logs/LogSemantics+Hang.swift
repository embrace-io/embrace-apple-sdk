//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import OpenTelemetryApi

extension LogType {
    public static let hang = LogType(system: "ios.hang")
}

public extension LogSemantics {
    struct Hang {
        public static let keyId = SemanticAttributes.logRecordUid.rawValue
        public static let keyProvider = "emb.provider"
        public static let keyPayload = "emb.payload"
        public static let keyPayLoadTimestamp = "emb.payload.timestamp"
        public static let keyDiagnosticTimestampStart = "diagnostic.timestamp_start"
        public static let keyDiagnosticTimestampEnd = "diagnostic.timestamp_end"

        public static let metrickitProvider = "metrickit"
    }
}
