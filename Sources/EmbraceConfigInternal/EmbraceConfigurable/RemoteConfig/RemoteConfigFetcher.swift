//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

class RemoteConfigFetcher {

    static let routePath = "/v2/config"

    let options: RemoteConfig.Options
    let logger: InternalLogger
    let session: URLSession
    let operationQueue: OperationQueue

    public init(options: RemoteConfig.Options, logger: InternalLogger) {
        self.options = options
        self.logger = logger

        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = options.queue
        session = URLSession(
            configuration: options.urlSessionConfiguration,
            delegate: nil,
            delegateQueue: operationQueue
        )
    }

    func fetch(completion: @escaping (RemoteConfigPayload?, Data?) -> Void) {
        guard let request = newRequest() else {
            completion(nil, nil)
            return
        }

        // execute request
        let dataTask = session.dataTask(with: request) { [weak self] data, response, error in

            guard let data = data, error == nil else {
                self?.logger.error("Error fetching remote config:\n\(String(describing: error?.localizedDescription))")
                completion(nil, nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self?.logger.error("Error fetching remote config - Invalid response:\n\(String(describing: response?.description))")
                completion(nil, nil)
                return
            }

            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                self?.logger.error("Error fetching remote config - Invalid response:\n\(httpResponse.description))")
                completion(nil, nil)
                return
            }

            // decode JSON
            do {
                let payload = try JSONDecoder().decode(RemoteConfigPayload.self, from: data)

                self?.logger.info("Successfully fetched remote config")
                completion(payload, data)
            } catch {
                self?.logger.error("Error decoding remote config:\n\(error.localizedDescription)")
                // if a decoding issue happens, instead of returning `nil`, we provide a default `RemoteConfigPayload`
                completion(RemoteConfigPayload(), nil)
            }
        }

        dataTask.resume()
    }

    func buildURL() -> URL? {
        var components = URLComponents(string: options.apiBaseUrl)

        components?.path.append(Self.routePath)
        components?.queryItems = [
            URLQueryItem(name: "appId", value: options.appId),
            URLQueryItem(name: "osVersion", value: options.osVersion),
            URLQueryItem(name: "appVersion", value: options.appVersion),
            URLQueryItem(name: "sdkVersion", value: options.sdkVersion)
        ]

        return components?.url
    }

    func newRequest() -> URLRequest? {
        guard let url = buildURL() else {
            return nil
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(options.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpMethod = "GET"

        // ETag
        let cache = session.configuration.urlCache
        if let cachedResponse = cache?.cachedResponse(for: request)?.response as? HTTPURLResponse {
            let tag1 = cachedResponse.allHeaderFields["ETag"] as? String
            let tag2 = cachedResponse.allHeaderFields["Etag"] as? String
            if let eTag = tag1 ?? tag2 {
                request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
            }
        }

        return request
    }
}
