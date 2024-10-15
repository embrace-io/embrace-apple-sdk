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

        @objc public init(injectTracingHeader: Bool, requestsDataSource: URLSessionRequestsDataSource?) {
            self.injectTracingHeader = injectTracingHeader
            self.requestsDataSource = requestsDataSource
        }

        @objc public convenience override init() {
            self.init(injectTracingHeader: true, requestsDataSource: nil)
        }
    }
}
