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
        let properties = storage.fetchCustomProperties(sessionId: session.id, processId: session.processId)

        // build resources payload
        let resources: [EmbraceMetadata] = storage.fetchResources(
            sessionId: session.id,
            processId: session.processId
        )
        let resourcePayload = ResourcePayload(from: resources)

        // the experiments record is stored as a required resource but emitted as an attribute
        // on the session span (and excluded from the resource payload)
        let experiments = resources.first { $0.key == ExperimentsSemantics.key }?.value

        // build spans
        let (spans, spanSnapshots) = SpansPayloadBuilder.build(
            for: session,
            storage: storage,
            customProperties: properties,
            experiments: experiments
        )

        // build metadata payload
        var metadata: [EmbraceMetadata] = []

        let tags = storage.fetchPersonaTags(sessionId: session.id, processId: session.processId)
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
