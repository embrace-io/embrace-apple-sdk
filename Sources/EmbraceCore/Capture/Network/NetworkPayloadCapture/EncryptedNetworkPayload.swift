//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Security
import CryptoKit

struct EncryptedNetworkPayload: Encodable {

    let url: String
    let httpMethod: String

    let startTime: Int?
    let endTime: Int?

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
        sessionId: String?
    ) {
        guard let request = request,
              let url = request.url,
              let method = request.httpMethod else {
            return nil
        }

        self.url = url.absoluteString
        self.httpMethod = method

        self.startTime = startTime?.nanosecondsSince1970Truncated
        self.endTime = endTime?.nanosecondsSince1970Truncated

        self.matchedUrl = matchedUrl
        self.sessionId = sessionId

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

        // generate symmetric key
        let symmetricKey = SymmetricKey(size: .bits256)

        // encrypt payload using aes
        var encryptedData: Data?
        do {
            encryptedData = try AES.GCM.seal(data, using: symmetricKey).combined
        } catch {
            Embrace.logger.debug("Error encrypting payload with AES.GCM!:\n\(error.localizedDescription)")
        }
        guard let encryptedData = encryptedData else {
            return nil
        }

        // parse public key string
        var createKeyError: Unmanaged<CFError>?

        let attributes = [
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ] as CFDictionary

        guard let keyData = Data(base64Encoded: key),
              let publicKey = SecKeyCreateWithData(keyData as CFData, attributes, &createKeyError) else {

            if let createKeyError = createKeyError {
                Embrace.logger.debug("Error creating public key \(key)!:\n\(createKeyError)")
            } else {
                Embrace.logger.debug("Error creating public key \(key)!")
            }
            return nil
        }

        // validate encryption algorithm
        let algorithm: SecKeyAlgorithm = .rsaEncryptionPKCS1
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            Embrace.logger.debug("PKCS1 encryption not supported!")
            return nil
        }

        // get symmetric key data
        let symmetricKeyData = symmetricKey.withUnsafeBytes { body in
            Data(body)
        }

        // encrypt symmetric key using the asymmetric key
        var error: Unmanaged<CFError>?
        guard let encryptedSymmetricKey = SecKeyCreateEncryptedData(
            publicKey,
            algorithm,
            symmetricKeyData as CFData,
            &error
        ) as Data? else {
            if let error = error {
                Embrace.logger.debug("Encryption error:\n\(error)")
            }
            return nil
        }

        return EncryptedPayloadResult(
            mechanism: "hybrid",
            payload: encryptedData.base64EncodedString(),
            payloadAlgorithm: "AES.GCM",
            key: encryptedSymmetricKey.base64EncodedString(),
            keyAlgorithm: "RSA.PKCS1"
        )
    }
}

struct EncryptedPayloadResult {
    let mechanism: String
    let payload: String
    let payloadAlgorithm: String
    let key: String
    let keyAlgorithm: String
}
