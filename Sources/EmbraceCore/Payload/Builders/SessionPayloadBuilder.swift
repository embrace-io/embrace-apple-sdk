//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

class SessionPayloadBuilder {

    class func build(for session: EmbraceSession, storage: EmbraceStorage) -> PayloadEnvelope<[SpanPayload]>? {

        // fetch properties
        // note that these are scoped to the user session, so every part of the same
        // user session carries the same set
        let properties = storage.fetchCustomProperties(for: session)

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: session,
            storage: storage,
            customProperties: properties
        )

        // build resources payload
        let resources: [EmbraceMetadata] = storage.fetchResources(for: session)
        let resourcePayload = ResourcePayload(from: resources)

        // build metadata payload
        var metadata: [EmbraceMetadata] = []

        let tags = storage.fetchPersonaTags(for: session)
        metadata.append(contentsOf: properties)
        metadata.append(contentsOf: tags)
        let metadataPayload = MetadataPayload(from: metadata)

        // build payload
        return PayloadEnvelope(
            spans: spans,
            spanSnapshots: spanSnapshots,
            resource: resourcePayload,
            metadata: metadataPayload
        )
    }
}
