//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

enum EmbraceUploadOperationResult: Equatable {
    case success
    case failure
    case cancelled
}

typealias EmbraceUploadOperationCompletion = (_ result: EmbraceUploadOperationResult, _ attemptCount: Int) -> Void

class EmbraceUploadOperation: AsyncOperation, @unchecked Sendable {
    private let urlSession: URLSession
    private let queue: DispatchQueue
    private let metadataOptions: EmbraceUpload.MetadataOptions
    private let endpoint: URL
    private let identifier: String
    private let data: Data
    private let payloadTypes: String?
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
        payloadTypes: String? = nil,
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
        self.payloadTypes = payloadTypes
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

        completion?(.cancelled, attemptCount)
        finish()
    }

    override func execute() {
        let request = createRequest(
            endpoint: endpoint,
            data: data,
            identifier: identifier,
            metadataOptions: metadataOptions
        )

        sendRequest(request, retryCount: retryCount)
    }

    private func sendRequest(_ r: URLRequest, retryCount: Int) {
        var request = r

        // increment attempt count
        attemptCount += 1

        // update request's attempt count header
        request = updateRequest(request, attemptCount: attemptCount)

        // Use completion handler directly on all platforms
        task = urlSession.dataTask(
            with: request,
            completionHandler: { [weak self] data, response, error in
                self?.handleTaskCompletion(
                    data: data,
                    response: response,
                    error: error,
                    request: request,
                    retryCount: retryCount
                )
            })

        task?.resume()
    }

    private func handleTaskCompletion(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        request: URLRequest,
        retryCount: Int
    ) {
        // If the operation was cancelled, cancel() already fired the completion and called finish().
        // Just return to avoid double-completion and double-finish.
        guard !isCancelled else {
            return
        }

        // Check retry budget: -1 = unlimited, 0 = none, >0 = that many remaining
        let hasRetryBudget = (retryCount != 0)
        if hasRetryBudget && shouldRetry(basedOn: response, error: error) {
            let delay = exponentialBackoffBehavior.calculateDelay(
                forRetryNumber: attemptCount,
                appending: TimeInterval(getSuggestedDelay(fromResponse: response))
            )

            let nextRetryCount = retryCount > 0 ? retryCount - 1 : retryCount

            queue.asyncAfter(
                deadline: .now() + delay,
                execute: { [weak self] in
                    self?.sendRequest(request, retryCount: nextRetryCount)
                })
            return
        }

        // No retries left or non-retriable — determine result
        if let response = response as? HTTPURLResponse {
            logger?.debug(
                "Upload operation complete. Status: \(response.statusCode) URL: \(String(describing: response.url))"
            )
            if response.statusCode >= 200 && response.statusCode < 300 {
                completion?(.success, attemptCount)
            } else {
                completion?(.failure, attemptCount)
            }
        } else {
            completion?(.failure, attemptCount)
        }

        finish()
    }

    private func shouldRetry(
        basedOn response: URLResponse?,
        error: (any Error)?
    ) -> Bool {
        // handle network-related errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .unsupportedURL,
                .badURL:
                return false
            default:
                return true
            }
        }

        // all 4xx and 5xx are retriable
        if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 400 {
            return true
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
            let retryAfterDelay = Int(retryAfterHeaderValue)
        else {
            return 0
        }

        return retryAfterDelay
    }

    func createRequest(
        endpoint: URL,
        data: Data,
        identifier: String,
        metadataOptions: EmbraceUpload.MetadataOptions
    ) -> URLRequest {

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data

        addHeaders(to: &request)

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")

        return request
    }

    func addHeaders(to request: inout URLRequest) {
        request.setValue(metadataOptions.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(metadataOptions.apiKey, forHTTPHeaderField: "X-EM-AID")
        request.setValue(metadataOptions.deviceId, forHTTPHeaderField: "X-EM-DID")

        if let payloadTypes {
            request.setValue(payloadTypes, forHTTPHeaderField: "X-EM-PAYLOAD-TYPES")
        }
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
