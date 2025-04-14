//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import OpenTelemetryApi

/// This extension transforms an `OpenTelemetryApi.Severity` into the severities we deem appropriate
/// for use in Embrace, which are found in `EmbraceCommon.LogSeverity`.
extension Severity {
    /// Transforms `OpenTelemetryApi.Severity` to `EmbraceCommon.LogSeverity`
    /// - Returns: a `EmbraceCommon.LogSeverity`. The transformation could fail, that's why it's an `Optional`
    public func toLogSeverity() -> LogSeverity? {
        LogSeverity(rawValue: self.rawValue)
    }

    static public func fromLogSeverity(_ logSeverity: LogSeverity) -> Severity? {
        Severity(rawValue: logSeverity.number)
    }
}
