//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionCaptureService {
    /// Class used to setup a URLSessionCaptureService.
    public struct Options {
        /// Defines wether or not the Embrace SDK should inject the `traceparent` header into all network requests
        public let injectTracingHeader: Bool

        /// `URLSessionRequestsDataSource` instance that will manipulate all network requests
        /// before the Embrace SDK captures their data.
        public let requestsDataSource: URLSessionRequestsDataSource?

        /// List of urls to be ignored by this service.
        /// Any request's url that contains any of these strings will not be captured.
        public let ignoredURLs: [String]

        public init(
            injectTracingHeader: Bool = true,
            requestsDataSource: URLSessionRequestsDataSource? = nil,
            ignoredURLs: [String] = []
        ) {
            self.injectTracingHeader = injectTracingHeader
            self.requestsDataSource = requestsDataSource
            self.ignoredURLs = ignoredURLs
        }
    }
}
