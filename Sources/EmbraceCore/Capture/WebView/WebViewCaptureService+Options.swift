//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import Foundation

    extension WebViewCaptureService {
        /// Used to setup a WebViewCaptureService.
        public struct Options {
            /// Defines whether or not the Embrace SDK should remove the query params when capturing URLs from a web view.
            public let stripQueryParams: Bool

            /// Creates a new `Options` with the given values.
            /// - Parameter stripQueryParams: Whether the SDK should remove query params when capturing URLs from a web view.
            public init(stripQueryParams: Bool = false) {
                self.stripQueryParams = stripQueryParams
            }
        }
    }
#endif
