//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension LogType {
    /// Used for crash reports provided by the Crash Reporter
    public static let crash = LogType(system: "ios.crash")
}

extension LogSemantics {
    public struct Crash {
        public static let keyId = SemanticAttributes.logRecordUid.rawValue
        public static let keyProvider = "emb.provider"
        public static let keyPayload = "emb.payload"

        public static let ksCrashProvider = "kscrash"
        public static let metrickitProvider = "metrickit"
    }
}
