//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

extension LogSemantics {
    /// Attribute keys and values for hang logs.
    public struct Hang {
        public static let keyId = LogSemantics.Payload.keyId
        public static let keyProvider = LogSemantics.Payload.keyProvider
        public static let keyPayload = LogSemantics.Payload.keyPayload
        public static let keyPayLoadTimestamp = LogSemantics.Payload.keyPayLoadTimestamp
        public static let keyDiagnosticTimestampStart = "diagnostic.timestamp_start"
        public static let keyDiagnosticTimestampEnd = "diagnostic.timestamp_end"

        public static let metrickitProvider = LogSemantics.Payload.metrickitProvider
    }
}
