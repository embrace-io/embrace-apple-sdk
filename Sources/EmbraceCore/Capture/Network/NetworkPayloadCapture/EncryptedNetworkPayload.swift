//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CommonCrypto
import CryptoKit
import Foundation
import Security

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

struct EncryptedNetworkPayload: Encodable {

    let url: String
    let httpMethod: String
    #if os(watchOS)
        let startTime: Int64?
        let endTime: Int64?
    #else
        let startTime: Int?
        let endTime: Int?
    #endif
    let matchedUrl: String
    let sessionId: String?

    let requestBody: String?
    let requestBodySize: Int?
    let requestQuery: String?
    let requestHeaders: [String: String]

    let responseBody: String?
    let responseBodySize: Int?
    let responseHeaders: [String: String]?
    let responseStatus: Int?

    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case url
        case httpMethod = "http-method"

        case startTime = "start-time"
        case endTime = "end-time"

        case matchedUrl = "matched-url"
        case sessionId = "session-id"

        case requestBody = "request-body"
        case requestBodySize = "request-body-size"
        case requestQuery = "request-query"
        case requestHeaders = "request-headers"

        case responseBody = "response-body"
        case responseBodySize = "response-body-size"
        case responseHeaders = "response-headers"
        case responseStatus = "response-status"

        case errorMessage = "error-message"
    }

    init?(
        request: URLRequest?,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        startTime: Date?,
        endTime: Date?,
        matchedUrl: String,
        sessionId: EmbraceIdentifier?
    ) {
        guard let request = request,
            let url = request.url,
            let method = request.httpMethod
        else {
            return nil
        }

        self.url = url.absoluteString
        self.httpMethod = method

        self.startTime = startTime?.nanosecondsSince1970Truncated
        self.endTime = endTime?.nanosecondsSince1970Truncated

        self.matchedUrl = matchedUrl
        self.sessionId = sessionId?.stringValue

        if let body = request.httpBody {
            self.requestBody = String(data: body, encoding: .utf8)
            self.requestBodySize = body.count
        } else {
            self.requestBody = nil
            self.requestBodySize = nil
        }

        self.requestQuery = url.query
        self.requestHeaders = request.allHTTPHeaderFields ?? [:]

        if let data = data {
            self.responseBody = String(data: data, encoding: .utf8)
            self.responseBodySize = data.count
        } else {
            self.responseBody = nil
            self.responseBodySize = nil
        }

        if let response = response as? HTTPURLResponse {
            self.responseHeaders = response.allHeaderFields as? [String: String] ?? [:]
            self.responseStatus = response.statusCode
        } else {
            self.responseHeaders = nil
            self.responseStatus = nil
        }

        if let error = error {
            self.errorMessage = error.localizedDescription
        } else {
            self.errorMessage = nil
        }
    }

    /// Returns the encrypted json representation of this object, along with the necessary things to decrypt the data.
    /// We are use hybrid encryption with AES and RSA.
    /// First we encrypt the payload using aes-256-cbc with a randomly generated symmetric key and iv.
    /// Afterwards we encrypt the symmetric key using RSA and the public key provided.
    /// In order to decrypt the data, the user will have to first decrypt the symmetric key using their private key with RSA.
    /// After that they'll have the symmetric key to decrypt the data using aes-256-cbc.
    /// Note: Both the symmetric key and iv are converted into hex strings for easier use with openssl commands during decryption.
    func encrypted(withKey key: String) -> EncryptedPayloadResult? {

        // encode json payload
        var data: Data?
        do {
            data = try JSONEncoder().encode(self)
        } catch {
            Embrace.logger.debug("Error encoding `EncryptedNetworkPayload`:\n\(error.localizedDescription)")
        }
        guard let data = data else {
            return nil
        }

        // encrypt payload
        guard let aesResult = EncryptionHelper.aesEncrypt(data: data) else {
            Embrace.logger.debug("Error with AES encryption!")
            return nil
        }

        // encrypt symmetric key
        guard let hexKeyData = aesResult.key.hexString.data(using: .utf8),
            let rsaResult = EncryptionHelper.rsaEncrypt(publicKey: key, data: hexKeyData)
        else {
            Embrace.logger.debug("Error with RSA encryption!")
            return nil
        }

        return EncryptedPayloadResult(
            mechanism: "hybrid",
            payload: aesResult.data.base64EncodedString(),
            payloadAlgorithm: aesResult.algorithm,
            key: rsaResult.data.base64EncodedString(),
            keyAlgorithm: rsaResult.algorithm,
            iv: aesResult.iv.hexString
        )
    }
}

struct EncryptedPayloadResult {
    let mechanism: String
    let payload: String
    let payloadAlgorithm: String
    let key: String
    let keyAlgorithm: String
    let iv: String
}

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
