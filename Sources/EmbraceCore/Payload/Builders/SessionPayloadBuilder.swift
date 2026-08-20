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
        let properties = storage.fetchCustomProperties(sessionId: session.idRaw, processId: session.processIdRaw)

        // Fetch the experiments tracked by the process this session belongs to.
        // This may be an earlier process, so it can't be read from the handler in memory.
        let experiments = storage.fetchMetadata(
            key: SpanSemantics.keyExperiments,
            type: .requiredResource,
            lifespan: .process,
            lifespanId: session.processIdRaw
        )?.value

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: session,
            storage: storage,
            customProperties: properties,
            experiments: experiments
        )

        // build resources payload
        let resources: [EmbraceMetadata] = storage.fetchResources(
            sessionId: session.idRaw, processId: session.processIdRaw)
        let resourcePayload = ResourcePayload(from: resources)

        // build metadata payload
        var metadata: [EmbraceMetadata] = []

        let tags = storage.fetchPersonaTags(sessionId: session.idRaw, processId: session.processIdRaw)
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
