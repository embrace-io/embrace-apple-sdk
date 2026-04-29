//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

// MARK: - EmbraceMetadataProvider
extension DefaultOTelSignalsHandler: EmbraceMetadataProvider {

    /// Returns the identifier for the current Embrace session, or `nil` when no session is active.
    package var currentSessionId: EmbraceIdentifier? {
        sessionController?.currentSession?.id
    }

    /// Returns the identifier for the current process.
    package var currentProcessId: EmbraceIdentifier {
        ProcessIdentifier.current
    }

    /// Returns the foreground/background state of the current Embrace session.
    package var currentSessionState: SessionState {
        sessionController?.currentSession?.state ?? .unknown
    }
}
