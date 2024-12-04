//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

enum EmbraceUploadOperationResult: Equatable {
    case success
    case failure(retriable: Bool)
}

typealias EmbraceUploadOperationCompletion = (_ result: EmbraceUploadOperationResult, _ attemptCount: Int) -> Void

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

        completion?(.failure(retriable: true), attemptCount)
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
            guard let strongSelf = self else {
                return
            }
            // retry?
            if retryCount > 0 && strongSelf.shouldRetry(basedOn: response, error: error) {
                // calculates the necessary delay before retrying the request
                let delay = strongSelf.exponentialBackoffBehavior.calculateDelay(
                    forRetryNumber: (strongSelf.retryCount - (retryCount - 1)),
                    appending: strongSelf.getSuggestedDelay(fromResponse: response)
                )

                // retry request on the same queue after `delay`
                strongSelf.queue.asyncAfter(deadline: .now() + .seconds(delay), execute: {
                    strongSelf.sendRequest(request, retryCount: retryCount - 1)
                })
                return
            }

            // check success
            if let response = response as? HTTPURLResponse {
                strongSelf.logger?.debug("Upload operation complete. Status: \(response.statusCode) URL: \(String(describing: response.url))")
                if response.statusCode >= 200 && response.statusCode < 300 {
                    strongSelf.completion?(.success, strongSelf.attemptCount)
                } else {
                    let isRetriable = strongSelf.shouldRetry(basedOn: response, error: error)
                    strongSelf.completion?(.failure(retriable: isRetriable), strongSelf.attemptCount)
                }

            // no retries left, send completion
            } else {
                let isRetriable = strongSelf.shouldRetry(basedOn: response, error: error)
                strongSelf.completion?(.failure(retriable: isRetriable), strongSelf.attemptCount)
            }

            strongSelf.finish()
        })

        task?.resume()
    }

    private func shouldRetry(
        basedOn response: URLResponse?,
        error: (any Error)?
    ) -> Bool {
        // handle network-related errors
        if let nsError = error as? URLError {
            switch nsError.code {
            case .cancelled,
                    .unsupportedURL,
                    .badURL,
                    .userAuthenticationRequired,
                    .secureConnectionFailed,
                    .serverCertificateUntrusted,
                    .dnsLookupFailed:
                return false
            default:
                return true
            }
        }

        // handle HTTP status codes:
        // retry only if is an error (client/server) and statusCode is not 429
        if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 400 {
            switch statusCode {
            // this status code ("Too Many Requests") indicates that the server has applied rate limiting to protect itself from excessive requests.
            // instead of dropping the request, we should retry this operation at a later time.
            case 429:
                return true
            // server-side errors (5xx): These indicate issues on the server side that may be temporary, so retrying is appropriate.
            case 500...599:
                return true
            // default case for other 4xx errors: These typically indicate client-side issues (e.g. invalid requests) and should not be retried.
            default:
                return false
            }
        }

        // retry for all other non-handled cases with errors
        return error != nil
    }
    
    /// Extracts the suggested delay from `Retry-After` header from the `URLResponse` if present.
    /// - Parameter response: the URLResponse recevied when executing a request.
    /// - Returns:the time in seconds (as `Int`) extracted from the `Retry-After` header.
    private func getSuggestedDelay(fromResponse response: URLResponse?) -> Int {
        guard let httpResponse = response as? HTTPURLResponse,
              let retryAfterHeaderValue = httpResponse.allHeaderFields["Retry-After"] as? String,
              let retryAfterDelay = Int(retryAfterHeaderValue) else {
            return 0
        }

        return retryAfterDelay
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
