//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

struct LogPayloadBuilder {
    static func build(log: LogRecord) -> LogPayload {
        var finalAttributes: [Attribute] = log.attributes.map { entry in
            Attribute(key: entry.key, value: entry.value.description)
        }

        finalAttributes.append(.init(key: "log.record.uid", value: log.identifier.toString))

        return .init(timeUnixNano: String(Int(log.timestamp.nanosecondsSince1970)),
                     severityNumber: log.severity.number,
                     severityText: log.severity.text,
                     body: log.body,
                     attributes: finalAttributes)
    }
}
