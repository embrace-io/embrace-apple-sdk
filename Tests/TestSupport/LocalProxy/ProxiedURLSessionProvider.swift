//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct ProxiedURLSessionProvider {
    public static func `default`() -> URLSession {
        with(configuration: .default)
    }

    public static func with(
        configuration: URLSessionConfiguration,
        delegate: URLSessionDelegate? = nil,
        queue: OperationQueue? = nil
    ) -> URLSession {
        configuration.protocolClasses = [URLTestProxy.self]
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
    }
}
