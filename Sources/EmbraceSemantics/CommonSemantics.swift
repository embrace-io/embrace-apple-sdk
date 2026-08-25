//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

/// Namespace for the OpenTelemetry attribute keys that Embrace stamps on more than one kind of signal.
///
/// `SpanSemantics`, `LogSemantics` and `SpanEventSemantics` expose these keys under their own
/// names for convenience at the call site, but this struct holds the single source of truth for
/// the actual values.
public struct CommonSemantics {
    /// The `EmbraceType` of the signal.
    public static let keyEmbraceType = "emb.type"

    /// `session.id` identifies the **user session** in v7 (not the part).
    /// Stamped on every span and log (empty string when unknown).
    public static let keySessionId = "session.id"

    /// `emb.user_session_id` — same value as `session.id` for now (until a future override
    /// API lets customers override `session.id` independently). Stamped on every span and log.
    public static let keyUserSessionId = "emb.user_session_id"

    /// `emb.session_part_id` — the session part UUID (the value `session.id` had historically).
    /// Stamped on every span and log.
    public static let keyPartId = "emb.session_part_id"

    /// The state the application was in when the signal was recorded.
    public static let keyState = "emb.state"

    /// Marks a signal as private to Embrace: it is uploaded to the Embrace backend for diagnostic
    /// purposes, but never stored locally nor forwarded to processors or exporters set by the user.
    public static let keyPrivate = "emb.private"

    /// Experiments and feature flags the user is enrolled in during the current process.
    public static let keyExperiments = "emb.experiments"
}
