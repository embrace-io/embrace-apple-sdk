//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

class RemoteConfigFetcher {

    static let routePath = "/v2/config"

    let options: EmbraceConfig.Options
    let session: URLSession
    let operationQueue: OperationQueue

    init(options: EmbraceConfig.Options) {
        self.options = options

        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = options.queue
        session = URLSession(
            configuration: options.urlSessionConfiguration,
            delegate: nil,
            delegateQueue: operationQueue
        )
    }

    public func fetch(completion: @escaping (RemoteConfigPayload?) -> Void) {
        guard let request = newRequest() else {
            completion(nil)
            return
        }

        // execute request
        let dataTask = session.dataTask(with: request) { data, response, error in

            guard let data = data, error == nil else {
                ConsoleLog.error("Error fetching remote config:\n\(String(describing: error?.localizedDescription))")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                ConsoleLog.error("Error fetching remote config - Invalid response:\n\(String(describing: response?.description))")
                completion(nil)
                return
            }

            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                ConsoleLog.error("Error fetching remote config - Invalid response:\n\(httpResponse.description))")
                completion(nil)
                return
            }

            // decode JSON
            do {
                let payload = try JSONDecoder().decode(RemoteConfigPayload.self, from: data)

                ConsoleLog.info("Succesfully fetched remote config")
                completion(payload)
            } catch {
                ConsoleLog.error("Error decoding remote config:\n\(error.localizedDescription)")
                completion(nil)
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
            URLQueryItem(name: "deviceId", value: options.deviceId)
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
