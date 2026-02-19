//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation

@testable import EmbraceOTelBridge

class MockMetadataProvider: EmbraceMetadataProvider {
    var currentSessionId: EmbraceIdentifier = EmbraceIdentifier(stringValue: "test-session-id")
    var currentProcessId: EmbraceIdentifier = EmbraceIdentifier(stringValue: "test-process-id")
    var currentSessionState: SessionState = .foreground

    func userProperties(sessionId: EmbraceIdentifier) -> EmbraceAttributes {
        return ["user.id": "test-user"]
    }
}
