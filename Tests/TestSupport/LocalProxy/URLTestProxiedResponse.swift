//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public class URLTestProxiedResponse {
    public let data: Data?
    public let response: URLResponse?
    public let error: Error?

    public required init(data: Data?, response: URLResponse?, error: Error?) {
        self.data = data
        self.response = response
        self.error = error
    }

    public static func sucessful(withData data: Data, response: URLResponse) -> URLTestProxiedResponse {
        self.init(data: data, response: response, error: nil)
    }

    public static func failure(withError error: Error, response: URLResponse, data: Data? = nil) -> URLTestProxiedResponse {
        self.init(data: data, response: response, error: error)
    }
}
