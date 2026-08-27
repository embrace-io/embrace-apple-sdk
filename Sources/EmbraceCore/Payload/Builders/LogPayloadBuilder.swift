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

    /// Builds a single-log payload.
    ///
    /// - Parameters:
    ///   - userSessionId: User session the log belongs to. When present, resources are resolved
    ///                    through the user session and the given process.
    ///   - processId: Process the log belongs to, or `nil` when it can't be determined. A crash
    ///                recovered from an earlier launch has to pass the process that crashed, so its
    ///                resources describe that process rather than the one building the payload.
    ///                There is deliberately no default: a log attributed to the wrong process
    ///                reports another process's resources as if they were its own, so a caller that
    ///                cannot name the process has to say so and go without them.
    static func build(
        timestamp: Date,
        severity: EmbraceLogSeverity,
        body: String,
        attributes: EmbraceAttributes,
        storage: EmbraceStorage?,
        userSessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier?
    ) -> PayloadEnvelope<[LogPayload]> {

        // build resources and metadata payloads
        var resources: [EmbraceMetadata] = []
        var metadata: [EmbraceMetadata] = []

        if let storage = storage, let processId = processId {
            if let userSessionId = userSessionId {
                resources = storage.fetchResources(userSessionId: userSessionId, processId: processId)

                let properties = storage.fetchCustomProperties(userSessionId: userSessionId, processId: processId)
                let tags = storage.fetchPersonaTags(userSessionId: userSessionId, processId: processId)
                metadata.append(contentsOf: properties)
                metadata.append(contentsOf: tags)
            } else {
                resources = storage.fetchResourcesForProcessId(processId)
                metadata = storage.fetchPersonaTagsForProcessId(processId)
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
