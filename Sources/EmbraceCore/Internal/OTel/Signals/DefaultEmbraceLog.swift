//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

class DefaultEmbraceLog: EmbraceLog {
    let id: String
    let severity: EmbraceLogSeverity
    let type: EmbraceType
    let timestamp: Date
    let body: String
    let attributes: [String: String]
    let sessionId: EmbraceIdentifier?
    let processId: EmbraceIdentifier

    init(
        id: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date,
        body: String,
        attributes: [String: String] = [:],
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier = ProcessIdentifier.current
    ) {
        self.id = id
        self.severity = severity
        self.type = type
        self.timestamp = timestamp
        self.body = body
        self.attributes = attributes
        self.sessionId = sessionId
        self.processId = processId
    }
}
