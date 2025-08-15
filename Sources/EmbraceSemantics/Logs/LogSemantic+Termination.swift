//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension LogType {
    /// Used for crash reports provided by the Crash Reporter
    public static let termination = LogType(system: "ios.termination")
}

extension LogSemantics {
    public struct Termination {
    }
}
