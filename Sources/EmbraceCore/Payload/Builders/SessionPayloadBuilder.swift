//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal

class SessionPayloadBuilder {

    static var resourceName = "emb.session.upload_index"

    class func build(for sessionRecord: SessionRecord, storage: EmbraceStorage) -> PayloadEnvelope<[SpanPayload]>? {
        guard let sessionId = sessionRecord.id else {
            return nil
        }

        // increment counter or create resource if needed
        var resource = storage.fetchRequiredPermanentResource(key: resourceName)
        var counter: Int = -1

        if let resource = resource {
            counter = (Int(resource.value) ?? 0) + 1
            resource.value = String(counter)
            storage.save()
        } else {
            resource = storage.addMetadata(
                key: resourceName,
                value: "1",
                type: .requiredResource,
                lifespan: .permanent
            )
            counter = 1
        }

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: sessionRecord,
            storage: storage,
            sessionNumber: counter
        )

        // build resources payload
        let resources: [MetadataRecord] = storage.fetchResourcesForSessionId(sessionId)
        let resourcePayload =  ResourcePayload(from: resources)

        // build metadata payload
        var metadata: [MetadataRecord] = []
        let properties = storage.fetchCustomPropertiesForSessionId(sessionId)
        let tags = storage.fetchPersonaTagsForSessionId(sessionId)
        metadata.append(contentsOf: properties)
        metadata.append(contentsOf: tags)
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
