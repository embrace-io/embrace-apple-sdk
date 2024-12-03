//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionCaptureService {
    /// Class used to setup a URLSessionCaptureService.
    @objc(EMBURLSessionCaptureServiceOptions)
    public final class Options: NSObject {
        /// Defines wether or not the Embrace SDK should inject the `traceparent` header into all network requests
        @objc public let injectTracingHeader: Bool

        /// `URLSessionRequestsDataSource` instance that will manipulate all network requests
        /// before the Embrace SDK captures their data.
        @objc public let requestsDataSource: URLSessionRequestsDataSource?

        /// List of urls to be ignored by this service.
        /// Any request's url that contains any of these strings will not be captured.
        @objc public let ignoredURLs: [String]

        @objc public init(injectTracingHeader: Bool, requestsDataSource: URLSessionRequestsDataSource?, ignoredURLs: [String]) {
            self.injectTracingHeader = injectTracingHeader
            self.requestsDataSource = requestsDataSource
            self.ignoredURLs = ignoredURLs
        }

        @objc public convenience override init() {
            self.init(injectTracingHeader: true, requestsDataSource: nil, ignoredURLs: [])
        }
    }
}
