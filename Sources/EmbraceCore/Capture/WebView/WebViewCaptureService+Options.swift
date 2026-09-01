//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import Foundation

    extension WebViewCaptureService {
        /// Defines how the SDK should treat the fragment component of a URL captured from a web view.
        ///
        /// The fragment (everything after the first `#`) is resolved by the user agent alone and never sent to
        /// the server, so it is commonly used to carry values that are not meant to leave the browser, such as
        /// the access tokens returned by the OAuth 2.0 implicit grant. It is also used to carry information that
        /// is useful when debugging, such as the hash routes of a single page application.
        public enum FragmentHandling: Int {
            /// The fragment is captured exactly as it appears in the URL.
            case keep

            /// Values in `key=value` pairs are removed, and unstructured segments long enough to be a payload
            /// rather than a label are dropped. Hash routes and short anchors are preserved.
            case redact

            /// The fragment is removed from the captured URL entirely.
            case remove
        }

        /// Used to setup a WebViewCaptureService.
        public struct Options {
            /// Defines whether or not the Embrace SDK should remove the query params when capturing URLs from a web view.
            public let stripQueryParams: Bool

            /// Defines how the Embrace SDK should treat the fragment when capturing URLs from a web view.
            ///
            /// This setting is independent of `stripQueryParams`: whether a fragment is captured never depends on
            /// whether the URL has a query.
            public let fragmentHandling: FragmentHandling

            /// Creates a new `Options` with the given values.
            /// - Parameters:
            ///   - stripQueryParams: Whether the SDK should remove query params when capturing URLs from a web view.
            ///   - fragmentHandling: How the SDK should treat the fragment when capturing URLs from a web view.
            public init(
                stripQueryParams: Bool = false,
                fragmentHandling: FragmentHandling = .keep
            ) {
                self.stripQueryParams = stripQueryParams
                self.fragmentHandling = fragmentHandling
            }
        }
    }
#endif
