//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceStorageInternal
#endif

class SessionPayloadBuilder {

    static var resourceName = "emb.session.upload_index"

    class func build(for session: EmbraceSession, storage: EmbraceStorage) -> PayloadEnvelope<[SpanPayload]>? {

        // increment counter or create resource if needed
        let counter = storage.incrementCountForPermanentResource(key: resourceName)

        // fetch properties
        let properties = storage.fetchCustomProperties(sessionId: session.idRaw, processId: session.processIdRaw)

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: session,
            storage: storage,
            customProperties: properties,
            sessionNumber: counter,
        )

        // build resources payload
        let resources: [EmbraceMetadata] = storage.fetchResources(sessionId: session.idRaw, processId: session.processIdRaw)
        let resourcePayload =  ResourcePayload(from: resources)

        // build metadata payload
        var metadata: [EmbraceMetadata] = []

        let tags = storage.fetchPersonaTags(sessionId: session.idRaw, processId: session.processIdRaw)
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
