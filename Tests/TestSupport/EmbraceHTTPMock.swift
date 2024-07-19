//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension URL {
    private static var testNameKey: UInt8 = 4

    var testName: String? {
        get {
            return objc_getAssociatedObject(self, &URL.testNameKey) as? String
        }
        set {
            objc_setAssociatedObject(
                self,
                &URL.testNameKey,
                newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    init?(string: String, testName: String) {
        self.init(string: string)
        self.testName = testName
    }
}

public class EmbraceHTTPMock: URLProtocol {

    private static var mockedResponses = [String: MockResponse]()
    private static var requests = [String: [URLRequest]]()

    /// Adds a mocked response for a given url
    public class func mock(url: URL, response: MockResponse) {
        mockedResponses[createKey(fromURL: url)] = response
    }

    /// Adds a succesful mocked response for the given url
    public class func mock(url: URL, data: Data? = nil, statusCode: Int = 200) {
        mockedResponses[createKey(fromURL: url)] = MockResponse.withData(data ?? Data(), statusCode: statusCode)
    }

    /// Adds a mocked reponse with the given error, for the given url
    public class func mock(url: URL, error: NSError) {
        mockedResponses[createKey(fromURL: url)] = MockResponse.withError(error)
    }

    /// Adds a mocked response with an error with the given error code, for the given url
    public class func mock(url: URL, errorCode: Int) {
        mockedResponses[createKey(fromURL: url)] = MockResponse.withErrorCode(errorCode)
    }

    private class func createKey(fromURL url: URL) -> String {
        var key: String = url.absoluteString
        if let testName = url.testName {
            key.append("-\(testName)")
        }
        return key
    }

    /// Returns the executed requests for a given url, if any
    public class func requestsForUrl(_ url: URL) -> [URLRequest] {
        return requests[createKey(fromURL: url)] ?? []
    }

    /// Returns the total amount of requests that were executed.
    public class func totalRequestCount(_ testName: String = #function) -> Int {
        return requests
            .filter { $0.key.contains(testName) }
            .values
            .reduce(0) { $0 + $1.count }
    }

    public class func clearRequests() {
        requests.removeAll()
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
            let key = Self.createKey(fromURL: url)
            if EmbraceHTTPMock.requests[key] == nil {
                EmbraceHTTPMock.requests[key] = []
            }
            EmbraceHTTPMock.requests[key]?.append(request)

            if let response = EmbraceHTTPMock.mockedResponses[key] {
                if let data = response.data {
                    client?.urlProtocol(self, didLoad: data)

                    if let httpResponse = HTTPURLResponse(
                        url: url,
                        statusCode: response.statusCode,
                        httpVersion: nil,
                        headerFields: nil
                    ) {
                        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .allowed)
                    }
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
    private(set) var statusCode: Int = -1

    public static func withData(_ data: Data, statusCode: Int) -> MockResponse {
        var response = MockResponse()
        response.data = data
        response.statusCode = statusCode

        return response
    }

    public static func withError(_ error: NSError) -> MockResponse {
        var response = MockResponse()
        response.error = error
        response.statusCode = error.code

        return response
    }

    public static func withErrorCode(_ code: Int) -> MockResponse {
        var response = MockResponse()
        response.error = NSError(domain: TestConstants.domain, code: code)
        response.statusCode = code

        return response
    }
}
