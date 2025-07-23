//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

public struct LogSemantics {
    public static let keyEmbraceType = "emb.type"
    public static let keyId = SemanticAttributes.logRecordUid.rawValue
    public static let keyState = "emb.state"
    public static let keySessionId = "session.id"
    public static let keyStackTrace = "emb.stacktrace.ios"
    public static let keyPropertiesPrefix = "emb.properties.%@"

    public static let keyAttachmentId = "emb.attachment_id"
    public static let keyAttachmentSize = "emb.attachment_size"
    public static let keyAttachmentUrl = "emb.attachment_url"
    public static let keyAttachmentErrorCode = "emb.attachment_error_code"

    public static let attachmentTooLarge = "ATTACHMENT_TOO_LARGE"
    public static let attachmentLimitReached = "OVER_MAX_ATTACHMENTS"
}
