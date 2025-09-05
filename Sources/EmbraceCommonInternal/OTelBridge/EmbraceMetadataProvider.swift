//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Protocol used to provide Embrace specific information to 3rd party OTel implementations
protocol EmbraceMetadataProvider {

    /// Returns the identifier for the current Embrace session, if any
    var currentSessionId: EmbraceIdentifier { get }

    /// Returns the identifier for the current process
    var currentProcessId: EmbraceIdentifier { get }

    /// Returns the user properties for a given session identifier
    func userProperties(sessionId: EmbraceIdentifier) -> [String: String]
}
