//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct PayloadEnvelope<T: Codable>: Codable {
    var resource: ResourcePayload
    var metadata: MetadataPayload
    var version: String = "1.0" // TODO: Make this the actual version
    var type: String
    var data = [String: T]()
}

extension PayloadEnvelope<LogPayload> {
    init(data: T, resource: ResourcePayload, metadata: MetadataPayload) {
        type = "logs"
        self.data["logs"] = data
        self.resource = resource
        self.metadata = metadata
    }
}
