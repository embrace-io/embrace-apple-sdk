//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
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
}
