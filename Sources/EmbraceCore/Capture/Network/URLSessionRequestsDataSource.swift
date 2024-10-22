//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This protocol can be used to modify requests before the Embrace SDK
/// captures their data into OTel spans.
///
/// Example:
/// This could be useful if you need to obfuscate certain parts of a request path
/// if it contains sensitive data.
@objc public protocol URLSessionRequestsDataSource: NSObjectProtocol {

    /// This method is called before a request is captured in order to modify data the is captured
    /// by the URLSessionCaptureService
    /// The original request is not modified and is sent as is.
    ///
    /// See [OTEL Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/http/http-spans/)
    /// for the conventions around building HTTP Spans
    @objc func modifiedRequest(for request: URLRequest) -> URLRequest
}
