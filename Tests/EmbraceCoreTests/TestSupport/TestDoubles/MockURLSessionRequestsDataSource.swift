//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCore

class MockURLSessionRequestsDataSource: NSObject, URLSessionRequestsDataSource {

    var block: ((URLRequest) -> URLRequest)?

    func modifiedRequest(for request: URLRequest) -> URLRequest {
        return block?(request) ?? request
    }
}
