//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceSemantics
#endif

class SessionPayloadBuilder {

    class func build(for session: EmbraceSession, storage: EmbraceStorage) -> PayloadEnvelope<[SpanPayload]>? {

        // fetch properties
        // note that these are scoped to the user session, so every part of the same
        // user session carries the same set
        let properties = storage.fetchCustomProperties(for: session)

        // Fetch the experiments tracked by the process this session belongs to.
        // This may be an earlier process, so it can't be read from the handler in memory.
        let experiments = storage.fetchMetadata(
            key: SpanSemantics.keyExperiments,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: session.processId.stringValue
        )?.value

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: session,
            storage: storage,
            customProperties: properties,
            experiments: experiments
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
