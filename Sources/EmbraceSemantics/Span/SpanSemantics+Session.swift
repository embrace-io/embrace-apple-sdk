//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanType {
    public static let session = SpanType(ux: "session")
}

extension SpanSemantics {
    public struct Session {
        public static let name = "emb-session"
        public static let keyId = "session.id"
        public static let keyState = "emb.state"
        public static let keyColdStart = "emb.cold_start"
        public static let keyTerminated = "emb.terminated"
        public static let keyCleanExit = "emb.clean_exit"
        public static let keySessionNumber = "emb.session_number"
        public static let keyHeartbeat = "emb.heartbeat_time_unix_nano"
        public static let keyCrashId = "emb.crash_id"
    }
}
