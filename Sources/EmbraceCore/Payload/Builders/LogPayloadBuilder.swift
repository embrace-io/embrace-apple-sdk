//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceCommon

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

    static func build(
        timestamp: Date,
        severity: LogSeverity,
        body: String,
        attributes: [String: String],
        storage: EmbraceStorage?,
        sessionId: SessionIdentifier?
    ) -> PayloadEnvelope<[LogPayload]> {

        // build resources and metadata payloads
        var resources: [MetadataRecord] = []
        var metadata: [MetadataRecord] = []

        if let storage = storage {
            do {
                if let sessionId = sessionId {
                    resources = try storage.fetchResourcesForSessionId(sessionId)
                    metadata = try storage.fetchCustomPropertiesForSessionId(sessionId)
                } else {
                    resources = try storage.fetchResourcesForProcessId(ProcessIdentifier.current)
                }
            } catch {
                Embrace.logger.error("Error fetching resources for crash log.")
            }
        }

        let finalAttributes: [Attribute] = attributes.map { entry in
            Attribute(key: entry.key, value: entry.value)
        }

        let logPayload = LogPayload(
            timeUnixNano: String(timestamp.nanosecondsSince1970Truncated),
            severityNumber: severity.rawValue,
            severityText: severity.text,
            body: body,
            attributes: finalAttributes
        )

        return .init(
            data: [logPayload],
            resource: ResourcePayload(from: resources),
            metadata: MetadataPayload(from: metadata)
        )
    }
}
