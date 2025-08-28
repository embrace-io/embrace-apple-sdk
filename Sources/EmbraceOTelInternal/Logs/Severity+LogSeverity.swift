//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// This extension transforms an `OpenTelemetryApi.Severity` into the severities we deem appropriate
/// for use in Embrace, which are found in `EmbraceCommon.LogSeverity`.
extension Severity {
    /// Transforms `OpenTelemetryApi.Severity` to `EmbraceCommon.LogSeverity`
    /// - Returns: a `EmbraceCommon.LogSeverity`. The transformation could fail, that's why it's an `Optional`
    public func toLogSeverity() -> EmbraceLogSeverity? {
        EmbraceLogSeverity(rawValue: self.rawValue)
    }

    static public func fromLogSeverity(_ logSeverity: EmbraceLogSeverity) -> Severity? {
        Severity(rawValue: logSeverity.rawValue)
    }
}
