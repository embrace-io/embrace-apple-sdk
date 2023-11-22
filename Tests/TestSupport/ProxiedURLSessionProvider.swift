//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct ProxiedURLSessionProvider {
    public static func `default`() -> URLSession {
        with(configuration: .default)
    }

    public static func with(configuration: URLSessionConfiguration, delegate: URLSessionDelegate? = nil, queue: OperationQueue? = nil) -> URLSession {
        configuration.protocolClasses = [URLTestProxy.self]
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
    }
}

class URLTestProxy: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client = client else { fatalError("There's something going on with the URL Loading System. This shouldn't happen") }
        let possibleMockResponse = request.url?.mockResponse ?? request.mockResponse
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
        // Check if we should do something here. Not necessary RN.
    }
}

public struct URLTestProxiedResponse {
    public let data: Data?
    public let response: URLResponse?
    public let error: Error?

    public init(data: Data?, response: URLResponse?, error: Error?) {
        self.data = data
        self.response = response
        self.error = error
    }

    public init(data: Data?, response: URLResponse?) {
        self.init(data: data, response: response, error: nil)
    }
}

public extension URL {
    private static var mockResponseKey: UInt8 = .random(in: 0...UInt8.max)

    var mockResponse: URLTestProxiedResponse? {
        get {
            return objc_getAssociatedObject(self, &URL.mockResponseKey) as? URLTestProxiedResponse
        }
        set {
            objc_setAssociatedObject(self, &URL.mockResponseKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

public extension URLRequest {
    private static var mockResponseKey: UInt8 = .random(in: 0...UInt8.max)

    var mockResponse: URLTestProxiedResponse? {
        get {
            return objc_getAssociatedObject(self, &URLRequest.mockResponseKey) as? URLTestProxiedResponse
        }
        set {
            objc_setAssociatedObject(self, &URLRequest.mockResponseKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
