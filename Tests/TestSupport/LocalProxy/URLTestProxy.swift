//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class URLTestProxy: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client = client else {
            fatalError("There's something going on with the URL Loading System. This shouldn't happen")
        }

        let possibleMockResponse = request.url?.mockResponse
        if let mockResponse = possibleMockResponse {
            if let response = mockResponse.response {
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = mockResponse.data {
                client.urlProtocol(self, didLoad: data)
            }
            if let error = mockResponse.error {
                client.urlProtocol(self, didFailWithError: error)
            }
        }
        client.urlProtocolDidFinishLoading(self)

    }

    override func stopLoading() {
        // Check if we should do something here. Seems it's not necessary right now.
    }
}
