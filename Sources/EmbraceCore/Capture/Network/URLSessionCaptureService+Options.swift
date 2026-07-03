//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionCaptureService {

    /// Configuration for W3C `traceparent` header propagation on captured network requests.
    public struct Traceparent {
        /// First-party domain allowlist. When not nil, only requests whose host matches one of these entries
        /// get a `traceparent` header.
        ///
        /// Entries are bare hostnames (e.g. `"test.com"`). No protocol prefix, no leading `.`,
        /// no path. Each entry matches hosts that equal it (`"test.com"`) or end with `.` + entry
        /// (`"api.test.com"`).
        ///
        /// Malformed entries (empty, containing `/`, containing whitespace, having a leading `.`)
        /// are dropped at init time and a warning is logged. The SDK does not throw for bad entries.
        ///
        /// Nil list (default) = no allowlist filter; the header is sent on every captured
        /// request that passes the other gates.
        /// An empty list means no domains should be captured.
        public let onlyAllowDomains: [String]?

        /// Creates a new `Traceparent` configuration.
        /// - Parameter onlyAllowDomains: First-party domain allowlist. When not `nil`, only requests to these domains get a `traceparent` header.
        public init(onlyAllowDomains: [String]? = nil) {
            self.onlyAllowDomains = Traceparent.validated(onlyAllowDomains)
        }

        private static func validated(_ entries: [String]?) -> [String]? {
            guard let entries = entries else { return nil }
            guard !entries.isEmpty else { return [] }
            var result: [String] = []
            for entry in entries {
                if entry.isEmpty {
                    Embrace.logger.warning(
                        "allowedDomains entry is empty and will be ignored."
                    )
                } else if entry.contains("/") {
                    Embrace.logger.warning(
                        "allowedDomains entry '\(entry)' contains '/' — use a bare hostname like 'test.com'; entry will be ignored."
                    )
                } else if entry.contains(" ") || entry.unicodeScalars.contains(where: { $0.value <= 0x20 }) {
                    Embrace.logger.warning(
                        "allowedDomains entry '\(entry)' contains whitespace — use a bare hostname like 'test.com'; entry will be ignored."
                    )
                } else if entry.hasPrefix(".") {
                    Embrace.logger.warning(
                        "allowedDomains entry '\(entry)' has a leading '.' — use a bare hostname like '\(entry.dropFirst())' instead; entry will be ignored."
                    )
                } else {
                    result.append(entry.lowercased())
                }
            }
            if result.isEmpty {
                Embrace.logger.warning(
                    "all domains in allowedDomains are invalid. The resulting allowedDomains list is empty."
                )
            }
            return result
        }
    }

    /// Used to setup a URLSessionCaptureService.
    public struct Options {

        /// `URLSessionRequestsDataSource` instance that will manipulate all network requests
        /// before the Embrace SDK captures their data.
        public let requestsDataSource: URLSessionRequestsDataSource?

        /// List of urls to be ignored by this service.
        /// Any request's url that contains any of these strings will not be captured.
        public let ignoredURLs: [String]

        /// Options for W3C `traceparent` header propagation.
        public let traceparent: Traceparent

        /// Creates a new `Options` with the given values.
        /// - Parameters:
        ///   - requestsDataSource: Data source used to manipulate requests before they are captured.
        ///   - ignoredURLs: Requests whose URL contains any of these strings are not captured.
        ///   - traceparent: W3C `traceparent` header propagation options.
        public init(
            requestsDataSource: URLSessionRequestsDataSource? = nil,
            ignoredURLs: [String] = [],
            traceparent: Traceparent = Traceparent()
        ) {
            self.requestsDataSource = requestsDataSource
            self.ignoredURLs = ignoredURLs
            self.traceparent = traceparent
        }
    }
}
