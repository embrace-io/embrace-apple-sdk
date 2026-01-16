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
        var finalAttributes: [Attribute] = log.allAttributes().map { entry in
            Attribute(key: entry.key, value: entry.valueRaw)
        }

        finalAttributes.append(.init(key: LogSemantics.keyId, value: log.idRaw))

        #if os(watchOS)
        return .init(
            timeUnixNano: String(Int64(log.timestamp.nanosecondsSince1970)),
            severityNumber: log.severity.number,
            severityText: log.severity.text,
            body: log.body,
            attributes: finalAttributes)
        #else
        return .init(
            timeUnixNano: String(Int(log.timestamp.nanosecondsSince1970)),
            severityNumber: log.severity.number,
            severityText: log.severity.text,
            body: log.body,
            attributes: finalAttributes)
        #endif
    }

    static func build(
        timestamp: Date,
        severity: LogSeverity,
        body: String,
        attributes: [String: String],
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
