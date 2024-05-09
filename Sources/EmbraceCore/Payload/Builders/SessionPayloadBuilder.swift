//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

class SessionPayloadBuilder {

    static var resourceName = "emb.session.upload_index"

    class func build(for sessionRecord: SessionRecord, storage: EmbraceStorage) -> PayloadEnvelope<[SpanPayload]> {
        var resource: MetadataRecord?

        do {
            // fetch resource
            resource = try storage.fetchRequriedPermanentResource(key: resourceName)
        } catch {
            ConsoleLog.debug("Error fetching \(resourceName) resource!")
        }

        // increment counter or create resource if needed
        var counter: Int = -1

        do {
            if var resource = resource {
                counter = (resource.integerValue ?? 0) + 1
                resource.value = .string(String(counter))
                try storage.updateMetadata(resource)
            } else {
                resource = try storage.addMetadata(
                    key: resourceName,
                    value: "1",
                    type: .requiredResource,
                    lifespan: .permanent
                )
                counter = 1
            }
        } catch {
            ConsoleLog.debug("Error updating \(resourceName) resource!")
        }

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: sessionRecord,
            storage: storage,
            sessionNumber: counter
        )

        // build resources payload
        var resources: [MetadataRecord] = []
        do {
            resources = try storage.fetchResourcesForSessionId(sessionRecord.id)
        } catch {
            ConsoleLog.error("Error fetching resources for session \(sessionRecord.id.toString)")
        }
        let resourcePayload =  ResourcePayload(from: resources)

        // build metadata payload
        var metadata: [MetadataRecord] = []
        do {
            metadata = try storage.fetchCustomPropertiesForSessionId(sessionRecord.id)
        } catch {
            ConsoleLog.error("Error fetching custom properties for session \(sessionRecord.id.toString)")
        }
        let metadataPayload =  MetadataPayload(from: metadata)

        // build payload
        return PayloadEnvelope(
            spans: spans,
            spanSnapshots: spanSnapshots,
            resource: resourcePayload,
            metadata: metadataPayload
        )
    }
}
