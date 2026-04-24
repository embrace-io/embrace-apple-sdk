//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension EmbraceIO {

    /// Appends additional key-value information to the next crash report.
    ///
    /// This method allows the addition of a key-value pair as an attribute to the next occurring
    /// crash that is reported during the lifetime of the process. This can be useful for adding context
    /// or debugging information that may help in analyzing the crash when exported.
    ///
    /// - Parameters:
    ///   - key: The key for the attribute.
    ///   - value: The value associated with the given key.
    public func appendCrashInfo(key: String, value: String) {
        Embrace.client?.appendCrashInfo(key: key, value: value)
    }

    /// Returns the last run end state.
    public func lastRunEndState() -> EmbraceLastRunEndState {
        Embrace.client?.lastRunEndState() ?? .unavailable
    }
}
