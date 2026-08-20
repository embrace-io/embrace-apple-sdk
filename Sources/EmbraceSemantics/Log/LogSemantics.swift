//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Namespace for the OpenTelemetry attribute keys used on Embrace logs.
public struct LogSemantics {
    public static let keyEmbraceType = "emb.type"
    public static let keyId = "log.record.uid"
    public static let keyState = "emb.state"

    /// `session.id` identifies the **user session** in v7 (not the part). Stamped on every log.
    public static let keySessionId = "session.id"

    /// `emb.user_session_id` — same value as `session.id` for now. Stamped on every log.
    public static let keyUserSessionId = "emb.user_session_id"

    /// `emb.session_part_id` — the part UUID. Stamped on every log.
    public static let keyPartId = "emb.session_part_id"

    public static let keyStackTrace = "emb.stacktrace.ios"
    public static let keyPropertiesPrefix = "emb.properties.%@"

    public static let keyAttachmentId = "emb.attachment_id"
    public static let keyAttachmentSize = "emb.attachment_size"
    public static let keyAttachmentUrl = "emb.attachment_url"
    public static let keyAttachmentErrorCode = "emb.attachment_error_code"

    public static let attachmentTooLarge = "ATTACHMENT_TOO_LARGE"
    public static let attachmentLimitReached = "OVER_MAX_ATTACHMENTS"
}
