//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import Foundation

@testable import EmbraceCore

class MockURLSessionRequestsDataSource: NSObject, URLSessionRequestsDataSource {

    var block: ((URLRequest) -> URLRequest)?

    private let _callCount = EmbraceMutex(0)
    var callCount: Int {
        _callCount.safeValue
    }

    func modifiedRequest(for request: URLRequest) -> URLRequest {
        _callCount.withLock { $0 += 1 }
        return block?(request) ?? request
    }

    /// When set, used to answer `spanParent(for:currentParentContext:)`. Otherwise the protocol's default is used.
    var spanParentBlock: ((URLRequest, EmbraceSpanContext?) -> EmbraceNetworkSpanParent)?

    private let _spanParentCalls = EmbraceMutex<[(request: URLRequest, currentParentContext: EmbraceSpanContext?)]>([])
    var spanParentCalls: [(request: URLRequest, currentParentContext: EmbraceSpanContext?)] {
        _spanParentCalls.safeValue
    }

    func spanParent(for request: URLRequest, currentParentContext: EmbraceSpanContext?) -> EmbraceNetworkSpanParent {
        _spanParentCalls.withLock { $0.append((request, currentParentContext)) }
        return spanParentBlock?(request, currentParentContext) ?? .default
    }
}

/// Requests data source that only implements `modifiedRequest(for:)`, relying on the protocol's
/// default `spanParent(for:currentParentContext:)`.
class MinimalURLSessionRequestsDataSource: URLSessionRequestsDataSource {
    func modifiedRequest(for request: URLRequest) -> URLRequest {
        return request
    }
}

/// Network span parent provider returning a fixed context.
class MockNetworkSpanParentProvider: NetworkSpanParentProvider {
    var context: EmbraceSpanContext?

    init(context: EmbraceSpanContext?) {
        self.context = context
    }

    func currentContext() -> EmbraceSpanContext? {
        return context
    }
}
