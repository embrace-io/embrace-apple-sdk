//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public class EmbraceHTTPMock: URLProtocol {

    private static var mockedResponses = [URL: MockResponse]()
    private static var requests = [URL: [URLRequest]]()

    /// Call this on the setUp method of your XCTestCase instance
    public class func setUp() {
        mockedResponses.removeAll()
        requests.removeAll()
    }

    /// Adds a mocked response for a given url
    public class func mock(url: URL, response: MockResponse) {
        mockedResponses[url] = response
    }

    /// Adds a succesful mocked response for the given url
    public class func mock(url: URL, data: Data? = nil) {
        mockedResponses[url] = MockResponse.withData(data ?? Data())
    }

    /// Adds a mocked reponse with the given error, for the given url
    public class func mock(url: URL, error: NSError) {
        mockedResponses[url] = MockResponse.withError(error)
    }

    /// Adds a mocked response with an error with the given error code, for the given url
    public class func mock(url: URL, errorCode: Int) {
        mockedResponses[url] = MockResponse.withErrorCode(errorCode)
    }

    /// Returns the executed requests for a given url, if any
    public class func requestsForUrl(_ url: URL) -> [URLRequest] {
        return requests[url] ?? []
    }

    // MARK: - Internal
    public override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        if let url = request.url {
            if EmbraceHTTPMock.requests[url] == nil {
                EmbraceHTTPMock.requests[url] = []
            }
            EmbraceHTTPMock.requests[url]?.append(request)

            if let response = EmbraceHTTPMock.mockedResponses[url] {
                if let data = response.data {
                    client?.urlProtocol(self, didLoad: data)
                } else {
                    let error = response.error ?? genericServerError
                    client?.urlProtocol(self, didFailWithError: error)
                }
            } else {
                client?.urlProtocol(self, didFailWithError: genericServerError)
            }
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    private var genericServerError: NSError {
        return NSError(domain: TestConstants.domain, code: 500)
    }

    public override func stopLoading() {

    }
}

public struct MockResponse {
    private(set) var data: Data?
    private(set) var error: Error?

    public static func withData(_ data: Data) -> MockResponse {
        var response = MockResponse()
        response.data = data

        return response
    }

    public static func withError(_ error: NSError) -> MockResponse {
        var response = MockResponse()
        response.error = error

        return response
    }

    public static func withErrorCode(_ code: Int) -> MockResponse {
        var response = MockResponse()
        response.error = NSError(domain: TestConstants.domain, code: code)

        return response
    }
}
