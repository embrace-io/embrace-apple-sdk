//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Namespace for the OpenTelemetry attribute keys used on Embrace spans.
public struct SpanSemantics {
    public static let keyEmbraceType = CommonSemantics.keyEmbraceType

    /// `session.id` identifies the **user session** in v7 (not the part). Stamped on every span.
    public static let keySessionId = CommonSemantics.keySessionId

    /// Marks a span as private to Embrace: it is uploaded to the Embrace backend for diagnostic
    /// purposes, but never stored locally nor forwarded to processors or exporters set by the user.
    public static let keyPrivate = CommonSemantics.keyPrivate

    public static let keyErrorCode = "emb.error_code"

    public static let keyNSErrorMessage = "error.message"
    public static let keyNSErrorCode = "error.code"

    public static let keyAutoTerminationCode = "emb.auto_termination.code"

    /// Experiments and feature flags the user is enrolled in during the current process.
    public static let keyExperiments = CommonSemantics.keyExperiments
}
