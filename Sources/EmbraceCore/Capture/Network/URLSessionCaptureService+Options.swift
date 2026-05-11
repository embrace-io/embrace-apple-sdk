//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension URLSessionCaptureService {

    /// Configuration for W3C `traceparent` header propagation on captured network requests.
    @objc(EMBURLSessionCaptureServiceTraceparentOptions)
    public final class Traceparent: NSObject {
        /// First-party domain allowlist. Only requests whose host matches one of these entries
        /// get a `traceparent` header.
        ///
        /// Entries are bare hostnames (e.g. `"test.com"`). No protocol prefix, no leading `.`,
        /// no path. Each entry matches hosts that equal it (`"test.com"`) or end with `.` + entry
        /// (`"api.test.com"`).
        ///
        /// Malformed entries (empty, containing `/`, containing whitespace, having a leading `.`)
        /// are dropped at init time and a warning is logged. The SDK does not throw for bad entries.
        ///
        /// Empty list (default) = no allowlist filter; the header is sent on every captured
        /// request that passes the other gates.
        @objc public let allowedDomains: [String]

        @objc public init(allowedDomains: [String] = []) {
            self.allowedDomains = Traceparent.validated(allowedDomains)
            super.init()
        }

        private static func validated(_ entries: [String]) -> [String] {
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
            return result
        }
    }

    /// Class used to setup a URLSessionCaptureService.
    @objc(EMBURLSessionCaptureServiceOptions)
    public final class Options: NSObject {

        /// `URLSessionRequestsDataSource` instance that will manipulate all network requests
        /// before the Embrace SDK captures their data.
        @objc public let requestsDataSource: URLSessionRequestsDataSource?

        /// List of urls to be ignored by this service.
        /// Any request's url that contains any of these strings will not be captured.
        @objc public let ignoredURLs: [String]

        /// Options for W3C `traceparent` header propagation.
        @objc public let traceparent: Traceparent

        @objc public init(
            requestsDataSource: URLSessionRequestsDataSource? = nil,
            ignoredURLs: [String] = [],
            traceparent: Traceparent = Traceparent()
        ) {
            self.requestsDataSource = requestsDataSource
            self.ignoredURLs = ignoredURLs
            self.traceparent = traceparent
        }

        /// - Note: `injectTracingHeader` is ignored. Injection rate is now controlled by remote
        ///   config (`traceparent_injection_pct_enabled`) for managed customers, or by a custom
        ///   `EmbraceConfigurable.traceparentInjectionEnabled` impl for non-managed setups.
        @available(
            *,
            deprecated,
            message: "Use init(requestsDataSource:ignoredURLs:traceparent:) instead. injectTracingHeader is ignored."
        )
        @objc public init(
            injectTracingHeader: Bool,
            requestsDataSource: URLSessionRequestsDataSource?,
            ignoredURLs: [String],
            traceparent: Traceparent = Traceparent()
        ) {
            self.requestsDataSource = requestsDataSource
            self.ignoredURLs = ignoredURLs
            self.traceparent = traceparent
        }

        @objc public convenience override init() {
            self.init(requestsDataSource: nil, ignoredURLs: [], traceparent: Traceparent())
        }

        /// Deprecated. Injection rate is now controlled by remote config. This setter is a no-op.
        @available(
            *,
            deprecated,
            message: "Injection rate is now controlled via remote config (traceparent_injection_pct_enabled) for managed customers, or via EmbraceConfigurable.traceparentInjectionEnabled for non-managed setups. This property is now a no-op."
        )
        @objc public var injectTracingHeader: Bool {
            get { false }
            set { Options.logDeprecatedInjectTracingHeaderOnce() }
        }

        private static let _deprecationLogger: Void = {
            Embrace.logger.warning(
                """
                Options.injectTracingHeader is deprecated and has no effect. \
                Injection rate is controlled by remote config (traceparent_injection_pct_enabled) \
                for managed customers, or via a custom EmbraceConfigurable.traceparentInjectionEnabled \
                for non-managed setups. \
                NSF customers: you can safely remove this property — server-side migration preserves your settings.
                """
            )
        }()

        internal static func logDeprecatedInjectTracingHeaderOnce() {
            _ = _deprecationLogger
        }
    }
}
