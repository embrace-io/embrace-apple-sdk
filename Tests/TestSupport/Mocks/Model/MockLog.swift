//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation

public class MockLog: EmbraceLog {
    public var id: String
    public var severity: EmbraceLogSeverity
    public var type: EmbraceType
    public var timestamp: Date
    public var body: String
    public var attributes: EmbraceAttributes
    public var sessionId: EmbraceIdentifier?
    public var processId: EmbraceIdentifier

    public func setAttribute(key: String, value: EmbraceAttributeValue?) {
        attributes[key] = value
    }

    public init(
        id: String = EmbraceIdentifier.random.stringValue,
        severity: EmbraceLogSeverity = .info,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        body: String = "Mock",
        attributes: EmbraceAttributes = [:],
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier = .random
    ) {
        self.id = id
        self.severity = severity
        self.type = type
        self.timestamp = timestamp
        self.body = body
        self.sessionId = sessionId
        self.processId = processId
        self.attributes = attributes
    }
}
