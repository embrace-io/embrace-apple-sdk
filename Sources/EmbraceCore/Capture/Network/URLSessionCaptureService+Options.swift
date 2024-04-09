//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionCaptureService {
    /// Class used to setup a URLSessionCaptureService.
    @objc public final class Options: NSObject {
        /// Defines wether or not the Embrace SDK should inject the `traceparent` header into all network requests
        @objc public let injectTracingHeader: Bool

        /// `URLSessionRequestsDataSource` instance that will manipuate all network requests
        /// before the Embrace SDK captures their data.
        @objc public let requestsDataSource: URLSessionRequestsDataSource?

        @objc public init(injectTracingHeader: Bool, requestsDataSource: URLSessionRequestsDataSource?) {
            self.injectTracingHeader = injectTracingHeader
            self.requestsDataSource = requestsDataSource
        }

        @objc convenience override init() {
            self.init(injectTracingHeader: true, requestsDataSource: nil)
        }
    }
}
