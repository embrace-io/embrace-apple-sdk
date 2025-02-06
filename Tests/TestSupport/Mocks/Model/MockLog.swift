//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import OpenTelemetryApi

public class MockLog: EmbraceLog {
    public var idRaw: String
    public var processIdRaw: String
    public var severityRaw: Int
    public var body: String
    public var timestamp: Date
    public var attributes: [MockLogAttribute]

    public init(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue] = [:]
    ) {
        self.idRaw = id.toString
        self.processIdRaw = processId.hex
        self.severityRaw = severity.rawValue
        self.body = body
        self.timestamp = timestamp

        var finalAttributes: [MockLogAttribute] = []
        for (key, value) in attributes {
            let attribute = MockLogAttribute(key: key, value: value)
            finalAttributes.append(attribute)
        }
        self.attributes = finalAttributes
    }

    public func allAttributes() -> [any EmbraceLogAttribute] {
        return attributes
    }

    public func attribute(forKey key: String) -> (any EmbraceLogAttribute)? {
        return attributes.first(where: { $0.key == key })
    }

    public func setAttributeValue(value: AttributeValue, forKey key: String) {
        if var attribute = attribute(forKey: key) {
            attribute.value = value
            return
        }

        let attribute = MockLogAttribute(key: key, value: value)
        attributes.append(attribute)
    }
}

public class MockLogAttribute: EmbraceLogAttribute {
    public var key: String
    public var valueRaw: String = ""
    public var typeRaw: Int = 0

    public init(key: String, value: AttributeValue) {
        self.key = key
        self.valueRaw = value.description
        self.typeRaw = typeForValue(value).rawValue
    }
}
