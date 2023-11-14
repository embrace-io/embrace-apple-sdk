//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

typealias EmbraceUploadOperationCompletion = (_ cancelled: Bool, _ attemptCount: Int, _ error: Error?) -> Void

class EmbraceUploadOperation: AsyncOperation {

    private let urlSession: URLSession
    private let metadataOptions: EmbraceUpload.MetadataOptions
    private let endpoint: URL
    private let identifier: String
    private let data: Data
    private let retryCount: Int
    private var attemptCount: Int
    private let completion: EmbraceUploadOperationCompletion?

    private var task: URLSessionDataTask?

    init(
        urlSession: URLSession,
        metadataOptions: EmbraceUpload.MetadataOptions,
        endpoint: URL,
        identifier: String,
        data: Data,
        retryCount: Int,
        attemptCount: Int,
        completion: EmbraceUploadOperationCompletion? = nil
    ) {
        self.urlSession = urlSession
        self.metadataOptions = metadataOptions
        self.endpoint = endpoint
        self.identifier = identifier
        self.data = data
        self.retryCount = retryCount
        self.attemptCount = attemptCount
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

            // retry?
            if error != nil && retryCount > 0 {
                self?.sendRequest(request, retryCount: retryCount - 1)
                return
            }

            // check success
            if let response = response as? HTTPURLResponse {
                if response.statusCode >= 200 && response.statusCode < 300 {
                    self?.completion?(false, self?.attemptCount ?? 0, nil)
                } else {
                    self?.completion?(false, self?.attemptCount ?? 0, self?.incorrectStatusCodeError(response.statusCode))
                }

            // no retries left, send completion
            } else {
                self?.completion?(false, self?.attemptCount ?? 0, error)
            }

            self?.finish()
        })

        task?.resume()
    }

    private func incorrectStatusCodeError(_ code: Int) -> Error {
        return NSError(domain: "com.embrace", code: code, userInfo: [NSLocalizedDescriptionKey: "Invalid status code received!"])
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
