//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A rule that determines which network request/response payloads the SDK captures.
public struct NetworkPayloadCaptureRule: Equatable, Decodable {

    /// Unique identifier of the rule.
    public let id: String

    /// Regular expression matched against the request URL to decide if the payload is captured.
    public let urlRegex: String

    /// HTTP status codes the rule applies to. `nil` matches any status code.
    public let statusCodes: [Int]?

    /// HTTP method the rule applies to. `nil` matches any method.
    public let method: String?

    /// Time interval (in seconds) after creation before the rule expires.
    public let expiration: Double

    /// Public key used to encrypt the captured payload.
    public let publicKey: String

    /// The date at which the rule expires, computed from its creation time and `expiration`.
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

    public static func == (lhs: NetworkPayloadCaptureRule, rhs: NetworkPayloadCaptureRule) -> Bool {
        lhs.id == rhs.id
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
