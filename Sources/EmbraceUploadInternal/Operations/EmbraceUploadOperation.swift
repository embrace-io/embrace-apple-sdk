//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

typealias EmbraceUploadOperationCompletion = (_ cancelled: Bool, _ attemptCount: Int, _ error: Error?) -> Void

class EmbraceUploadOperation: AsyncOperation {

    private let urlSession: URLSession
    private let queue: DispatchQueue
    private let metadataOptions: EmbraceUpload.MetadataOptions
    private let endpoint: URL
    private let identifier: String
    private let data: Data
    private let retryCount: Int
    private let exponentialBackoffBehavior: EmbraceUpload.ExponentialBackoff
    private var attemptCount: Int
    private let logger: InternalLogger?
    private let completion: EmbraceUploadOperationCompletion?

    private var task: URLSessionDataTask?

    init(
        urlSession: URLSession,
        queue: DispatchQueue,
        metadataOptions: EmbraceUpload.MetadataOptions,
        endpoint: URL,
        identifier: String,
        data: Data,
        retryCount: Int,
        exponentialBackoffBehavior: EmbraceUpload.ExponentialBackoff,
        attemptCount: Int,
        logger: InternalLogger? = nil,
        completion: EmbraceUploadOperationCompletion? = nil
    ) {
        self.urlSession = urlSession
        self.queue = queue
        self.metadataOptions = metadataOptions
        self.endpoint = endpoint
        self.identifier = identifier
        self.data = data
        self.retryCount = retryCount
        self.exponentialBackoffBehavior = exponentialBackoffBehavior
        self.attemptCount = attemptCount
        self.logger = logger
        self.completion = completion
    }

    override func cancel() {
        super.cancel()

        task?.cancel()
        task = nil

        completion?(true, attemptCount, nil)
    }

    override func execute() {
        let request = createRequest()

        sendRequest(request, retryCount: retryCount)
    }

    private func sendRequest(_ r: URLRequest, retryCount: Int) {
        var request = r

        // increment attempt count
        attemptCount += 1

        // update request's attempt count header
        request = updateRequest(request, attemptCount: attemptCount)

        task = urlSession.dataTask(with: request, completionHandler: { [weak self] _, response, error in
            guard let self = self else {
                return
            }

            // retry?
            if self.shouldRetry(basedOn: response, retryCount: retryCount, error: error) {
                let delay = exponentialBackoffBehavior.calculateDelay(forRetryNumber: (self.retryCount - (retryCount - 1)))
                self.logger?.debug("Will retry request in \(delay)")
                queue.asyncAfter(deadline: .now() + .seconds(delay), execute: {
                    self.sendRequest(request, retryCount: retryCount - 1)
                })
                return
            }

            // check success
            if let response = response as? HTTPURLResponse {
                self.logger?.debug("Upload operation complete. Status: \(response.statusCode) URL: \(String(describing: response.url))")
                if response.statusCode >= 200 && response.statusCode < 300 {
                    self.completion?(false, self.attemptCount, nil)
                } else {
                    let returnError = EmbraceUploadError.incorrectStatusCodeError(response.statusCode)
                    self.completion?(false, self.attemptCount, returnError)
                }

            // no retries left, send completion
            } else {
                self.completion?(false, self.attemptCount, error)
            }

            self.finish()
        })

        task?.resume()
    }

    private func shouldRetry(
        basedOn response: URLResponse?,
        retryCount: Int,
        error: (any Error)?
    ) -> Bool {
        // No retries left
        guard retryCount > 0 else { return false }

        // Handle network-related errors
        if let nsError = error as? URLError {
            switch nsError.code {
            case .cancelled,
                    .unsupportedURL,
                    .cannotConnectToHost,
                    .badURL,
                    .userAuthenticationRequired,
                    .notConnectedToInternet,
                    .secureConnectionFailed,
                    .serverCertificateUntrusted,
                    .dnsLookupFailed:
                return false
            default:
                return true
            }
        }

        // Handle HTTP status codes:
        // Retry only if is an error (client/server) and statusCode is not 429
        if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 400 {
            switch statusCode {
            case 429: // Too many requests; we shouldn't retry.
                return false
            default:
                return true
            }
        }

        // Retry for all other non-handled cases with errors
        return error != nil
    }

    private func createRequest() -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        request.setValue(metadataOptions.userAgent, forHTTPHeaderField: "User-Agent")

        request.setValue(metadataOptions.apiKey, forHTTPHeaderField: "X-EM-AID")
        request.setValue(metadataOptions.deviceId, forHTTPHeaderField: "X-EM-DID")

        return request
    }

    private func updateRequest(_ r: URLRequest, attemptCount: Int) -> URLRequest {
        guard attemptCount > 1 else {
            return r
        }

        var request = r
        request.setValue(String(attemptCount - 1), forHTTPHeaderField: "x-emb-retry-count")

        return request
    }
}
