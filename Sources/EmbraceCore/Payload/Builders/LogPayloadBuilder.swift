//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

struct LogPayloadBuilder {
    static func build(log: EmbraceLog) -> LogPayload {
        var finalAttributes: [Attribute] = log.attributes.map { entry in
            Attribute(key: entry.key, value: String(describing: entry.value))
        }

        finalAttributes.append(.init(key: LogSemantics.keyId, value: log.id))

        return .init(
            timeUnixNano: String(EMBInt(log.timestamp.nanosecondsSince1970)),
            severityNumber: log.severity.rawValue,
            severityText: log.severity.name,
            body: log.body,
            attributes: finalAttributes)

    }

    static func build(
        timestamp: Date,
        severity: EmbraceLogSeverity,
        body: String,
        attributes: EmbraceAttributes,
        storage: EmbraceStorage?,
        sessionId: EmbraceIdentifier?
    ) -> PayloadEnvelope<[LogPayload]> {

        // build resources and metadata payloads
        var resources: [EmbraceMetadata] = []
        var metadata: [EmbraceMetadata] = []

        if let storage = storage {
            if let sessionId = sessionId {
                resources = storage.fetchResourcesForSessionId(sessionId)

                let properties = storage.fetchCustomPropertiesForSessionId(sessionId)
                let tags = storage.fetchPersonaTagsForSessionId(sessionId)
                metadata.append(contentsOf: properties)
                metadata.append(contentsOf: tags)
            } else {
                resources = storage.fetchResourcesForProcessId(ProcessIdentifier.current)
                metadata = storage.fetchPersonaTagsForProcessId(ProcessIdentifier.current)
            }
        }

        let finalAttributes: [Attribute] = attributes.map { entry in
            Attribute(key: entry.key, value: String(describing: entry.value))
        }

        let logPayload = LogPayload(
            timeUnixNano: String(timestamp.nanosecondsSince1970Truncated),
            severityNumber: severity.rawValue,
            severityText: severity.name,
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
