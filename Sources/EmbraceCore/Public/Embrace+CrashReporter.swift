//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension Embrace {
    /// Appends additional key-value information to the next crash report.
    ///
    /// This method allows the addition of a key-value pair as an attribute to the next occurring
    /// crash that is reported during the lifetime of the process. This can be useful for adding context
    /// or debugging information that may help in analyzing the crash when exported.
    ///
    /// - Parameters:
    ///   - key: The key for the attribute.
    ///   - value: The value associated with the given key.
    package func appendCrashInfo(key: String, value: String) {
        captureServices.crashReporter?.appendCrashInfo(key: key, value: value)
    }

    /// Returns the last run end state.
    package func lastRunEndState() -> EmbraceLastRunEndState {
        guard let crashReporterEndState = captureServices.crashReporter?.getLastRunState() else {
            return .unavailable
        }

        return EmbraceLastRunEndState(rawValue: crashReporterEndState.rawValue) ?? .unavailable
    }

}
