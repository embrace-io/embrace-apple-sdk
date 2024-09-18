//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct PayloadEnvelope<T: Encodable>: Encodable {
    var resource: ResourcePayload
    var metadata: MetadataPayload
    var version: String = "1.0"
    var type: String
    var data = [String: T]()
}

extension PayloadEnvelope<[LogPayload]> {
    init(data: [LogPayload], resource: ResourcePayload, metadata: MetadataPayload) {
        type = "logs"
        self.data["logs"] = data
        self.resource = resource
        self.metadata = metadata
    }
}

extension PayloadEnvelope<[SpanPayload]> {
    init(spans: [SpanPayload], spanSnapshots: [SpanPayload], resource: ResourcePayload, metadata: MetadataPayload) {
        type = "spans"
        self.data["spans"] = spans
        self.data["span_snapshots"] = spanSnapshots
        self.resource = resource
        self.metadata = metadata
    }
}
