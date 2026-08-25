//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Namespace for the OpenTelemetry attribute keys used on Embrace logs.
public struct LogSemantics {
    public static let keyEmbraceType = CommonSemantics.keyEmbraceType
    public static let keyId = "log.record.uid"
    public static let keyState = CommonSemantics.keyState

    /// `session.id` identifies the **user session** in v7 (not the part). Stamped on every log.
    public static let keySessionId = CommonSemantics.keySessionId

    /// `emb.user_session_id` — same value as `session.id` for now. Stamped on every log.
    public static let keyUserSessionId = CommonSemantics.keyUserSessionId

    /// `emb.session_part_id` — the part UUID. Stamped on every log.
    public static let keyPartId = CommonSemantics.keyPartId

    public static let keyStackTrace = "emb.stacktrace.ios"
    public static let keyPropertiesPrefix = "emb.properties.%@"

    /// Experiments and feature flags the user is enrolled in during the current process.
    public static let keyExperiments = CommonSemantics.keyExperiments

    /// Marks a log as private to Embrace: it is uploaded to the Embrace backend for diagnostic
    /// purposes, but never stored locally nor forwarded to processors or exporters set by the user.
    public static let keyPrivate = CommonSemantics.keyPrivate

    public static let keyAttachmentId = "emb.attachment_id"
    public static let keyAttachmentSize = "emb.attachment_size"
    public static let keyAttachmentUrl = "emb.attachment_url"
    public static let keyAttachmentErrorCode = "emb.attachment_error_code"

    public static let attachmentTooLarge = "ATTACHMENT_TOO_LARGE"
    public static let attachmentLimitReached = "OVER_MAX_ATTACHMENTS"
}
