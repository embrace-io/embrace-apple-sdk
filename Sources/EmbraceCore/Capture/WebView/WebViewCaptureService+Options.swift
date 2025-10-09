//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import Foundation

    extension WebViewCaptureService {
        /// Class used to setup a WebViewCaptureService.
        public struct Options {
            /// Defines wether or not the Embrace SDK should remove the query params when capturing URLs from a web view.
            public let stripQueryParams: Bool

            public init(stripQueryParams: Bool = false) {
                self.stripQueryParams = stripQueryParams
            }
        }
    }
#endif
