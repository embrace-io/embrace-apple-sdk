//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import Foundation

    extension WebViewCaptureService {
        /// Class used to setup a WebViewCaptureService.
        @objc(EMBWebViewCaptureServiceOptions)
        public final class Options: NSObject {
            /// Defines wether or not the Embrace SDK should remove the query params when capturing URLs from a web view.
            @objc public let stripQueryParams: Bool

            @objc public init(stripQueryParams: Bool) {
                self.stripQueryParams = stripQueryParams
            }

            @objc public convenience override init() {
                self.init(stripQueryParams: false)
            }
        }
    }
#else
    extension WebViewCaptureService {
        /// Class used to setup a WebViewCaptureService.
        @objc(EMBWebViewCaptureServiceOptions)
        public final class Options: NSObject {
        }
    }
#endif
