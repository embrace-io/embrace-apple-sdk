//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import EmbraceCommonInternal
import Foundation
import OpenTelemetryApi

public struct MockLog: EmbraceLog {
    public var id: String
    public var severity: EmbraceLogSeverity
    public var timestamp: Date
    public var body: String
    public var sessionId: EmbraceIdentifier?
    public var processId: EmbraceIdentifier
    public var attributes: [String: String]

    public mutating func setAttribute(key: String, value: String?) {
        attributes[key] = value
    }

    public init(
        id: String = EmbraceIdentifier.random.stringValue,
        severity: EmbraceLogSeverity = .info,
        timestamp: Date = Date(),
        body: String = "Mock",
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier = .random,
        attributes: [String : String] = [:]
    ) {
        self.id = id
        self.severity = severity
        self.timestamp = timestamp
        self.body = body
        self.sessionId = sessionId
        self.processId = processId
        self.attributes = attributes
    }

}
