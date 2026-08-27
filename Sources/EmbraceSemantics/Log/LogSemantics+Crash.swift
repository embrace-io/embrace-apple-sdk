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
        public static let keyId = LogSemantics.Payload.keyId
        public static let keyProvider = LogSemantics.Payload.keyProvider
        public static let keyPayload = LogSemantics.Payload.keyPayload

        public static let ksCrashProvider = LogSemantics.Payload.ksCrashProvider
        public static let metrickitProvider = LogSemantics.Payload.metrickitProvider
    }
}
