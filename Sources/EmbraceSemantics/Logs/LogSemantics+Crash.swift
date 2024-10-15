//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi

extension LogType {
    /// Used for crash reports provided by the Crash Reporter
    public static let crash = LogType(system: "ios.crash")
}

public extension LogSemantics {
    struct Crash {
        public static let keyId = SemanticAttributes.logRecordUid.rawValue
        public static let keyProvider = "emb.provider"
        public static let keyPayload = "emb.payload"
    }
}
