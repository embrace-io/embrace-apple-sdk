//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let session = EmbraceType(ux: "session")
}

extension SpanSemantics {
    /// Attribute keys and values for session spans.
    public struct Session {
        public static let name = "emb-session"

        /// `session.id` now identifies the **user session**, not the individual part.
        /// Stamped on every span and log (empty string when unknown).
        public static let keyId = "session.id"

        /// `emb.user_session_id` — same value as `session.id` for now (until a future override
        /// API lets customers override `session.id` independently). Stamped on every span and log.
        public static let keyUserSessionId = "emb.user_session_id"

        /// `emb.session_part_id` — the part UUID (the value `session.id` had historically).
        /// Stamped on every span and log.
        public static let keyPartId = "emb.session_part_id"

        public static let keyState = "emb.state"
        public static let keyColdStart = "emb.cold_start"
        public static let keyTerminated = "emb.terminated"
        public static let keyCleanExit = "emb.clean_exit"

        /// Globally-unique per-part counter (renamed from `emb.session_number`).
        public static let keySessionPartNumber = "emb.session_part_number"

        /// 1-indexed position of the current part within its user session.
        public static let keyUserSessionPartIndex = "emb.user_session_part_index"

        /// Wall-clock start of the user session, in nanoseconds since epoch.
        public static let keyUserSessionStartTs = "emb.user_session_start_ts"

        /// Max duration of the user session in seconds (config snapshot taken at user-session creation).
        public static let keyUserSessionMaxDurationSeconds = "emb.user_session_max_duration_seconds"

        /// Inactivity timeout in seconds (config snapshot taken at user-session creation).
        public static let keyUserSessionInactivityTimeoutSeconds = "emb.user_session_inactivity_timeout_seconds"

        /// `"1"` on the last part of a terminated user session; omitted otherwise.
        public static let keyIsFinalSessionPart = "emb.is_final_session_part"

        /// Termination reason on the last part of a terminated user session; omitted otherwise.
        public static let keyUserSessionTerminationReason = "emb.user_session_termination_reason"

        public static let keyHeartbeat = "emb.heartbeat_time_unix_nano"
        public static let keyCrashId = "emb.crash_id"
    }
}
