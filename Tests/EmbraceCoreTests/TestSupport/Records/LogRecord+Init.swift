//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal
import OpenTelemetryApi

extension LogRecord {
    convenience init(
        id: LogIdentifier,
        processId: ProcessIdentifier,
        severity: LogSeverity,
        body: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue]
    ) {
        self.init()

        self.idRaw = id.toString
        self.processIdRaw = processId.hex
        self.severityRaw = severity.rawValue
        self.body = body
        self.timestamp = timestamp

        for (key, value) in attributes {
            let attribute = LogAttributeRecord(key: key, value: value, log: self)
            self.attributes.append(attribute)
        }
    }
}

extension LogAttributeRecord {
    convenience init(
        key: String,
        value: AttributeValue,
        log: LogRecord
    ) {
        self.init()

        self.key = key
        self.valueRaw = value.description
        self.log = log
    }
}
