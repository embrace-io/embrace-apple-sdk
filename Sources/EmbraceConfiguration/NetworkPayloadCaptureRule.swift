//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc
public final class NetworkPayloadCaptureRule: NSObject, Decodable {
    public let id: String
    public let urlRegex: String
    public let statusCodes: [Int]?
    public let method: String?
    public let expiration: Double
    public let publicKey: String

    public var expirationDate: Date {
        return creationDate.addingTimeInterval(expiration)
    }

    private let creationDate: Date = Date()

    init(
        id: String,
        urlRegex: String,
        statusCodes: [Int]?,
        method: String?,
        expiration: Double,
        publicKey: String
    ) {
        self.id = id
        self.urlRegex = urlRegex
        self.statusCodes = statusCodes
        self.method = method
        self.expiration = expiration
        self.publicKey = publicKey
    }
}

extension NetworkPayloadCaptureRule {
    enum CodingKeys: String, CodingKey {
        case id
        case urlRegex = "url"
        case statusCodes = "status_codes"
        case method
        case expiration = "expires_in"
        case publicKey = "public_key"
    }
}

extension NetworkPayloadCaptureRule /* Equatable */ {
    public static func == (lhs: NetworkPayloadCaptureRule, rhs: NetworkPayloadCaptureRule) -> Bool {
        lhs.id == rhs.id
    }
}
