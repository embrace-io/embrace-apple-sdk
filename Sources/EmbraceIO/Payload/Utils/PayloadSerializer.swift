//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol PayloadSerializerType {
    func serializeAndGZipJson(_ json: Codable) -> PayloadSerializerResult
}

struct PayloadSerializerResult {
    var data: Data?
    var error: PayloadSerializer.Errors?
}

class PayloadSerializer: PayloadSerializerType {
    enum Errors: Error {
        case serializationFailed
    }

    func serializeAndGZipJson(_ json: Codable) -> PayloadSerializerResult {
        if let jsonPayload = try? JSONEncoder().encode(json) {
            // Missing gzip
            return .init(data: jsonPayload, error: nil)
        }
        return .init(data: nil, error: .serializationFailed)
    }
}
