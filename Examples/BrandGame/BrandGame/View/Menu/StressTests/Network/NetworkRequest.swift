//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension NetworkStressTest {
    struct NetworkRequest: Identifiable {

        let url: URL
        let idx: UInt

        var id: UInt { idx }

        init?(string: String, idx: UInt) {
            guard var components = URLComponents(string: string) else {
                return nil
            }

            var items = components.queryItems ?? []
            items.append(.init(name: "idx", value: String(idx)))
            components.queryItems = items

            guard let url = components.url else {
                return nil
            }

            self.url = url
            self.idx = idx
        }

        func execute(completion: @escaping (NetworkResponse?) -> Void) {
            let before = Date()

            let task = URLSession.shared.dataTask(with: url) { _, response, error in
                let after = Date()

                guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                    completion(nil)
                    return
                }

                let networkResponse = NetworkResponse(
                    id: self.idx,
                    requestURL: self.url,
                    response: httpResponse,
                    rtt: after.timeIntervalSince(before)
                )

                completion(networkResponse)
            }

            task.resume()
        }
    }

    struct NetworkResponse: Sendable, Identifiable {

        let id: UInt

        /// URL of the request
        let requestURL: URL

        /// The underlying HTTP response
        let response: HTTPURLResponse

        /// Round trip time, in seconds
        let rtt: TimeInterval
    }
}
