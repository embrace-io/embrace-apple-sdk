//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi

public struct LogSemantics {
    public static let keyEmbraceType = "emb.type"
    public static let keyId = SemanticAttributes.logRecordUid.rawValue
    public static let keyState = "emb.state"
    public static let keySessionId = "emb.session_id"
    public static let keyStackTrace = "emb.stacktrace.ios"
    public static let keyPropertiesPrefix = "emb.properties.%@"
}
