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

        func execute() async throws -> NetworkResponse {
            let before = Date()
            let (_, response) = try await URLSession.shared.data(from: url)
            let after = Date()

            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("Not a HTTP Response")
            }

            return NetworkResponse(id: idx, requestURL: url, response: httpResponse, rtt: after.timeIntervalSince(before))
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
