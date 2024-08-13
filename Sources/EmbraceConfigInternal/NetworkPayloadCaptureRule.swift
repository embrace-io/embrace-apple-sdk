//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct NetworkPayloadCaptureRule: Decodable, Equatable {

    let id: String
    let urlRegex: String
    let statusCodes: [Int]?
    let methods: [String]?
    let expiration: Double
    let publicKey: String

    var expirationDate: Date {
        return Date(timeIntervalSince1970: expiration)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case urlRegex = "url"
        case statusCodes = "status_code"
        case methods = "method"
        case expiration
        case publicKey = "public_key"
    }
}
