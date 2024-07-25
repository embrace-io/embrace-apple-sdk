//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This protocol can be used to modify requests before the Embrace SDK
/// captures their data into OTel spans.
///
/// Example:
/// This could be useful if you need to obfuscate certains parts of a request path
/// if it contains sensitive data.
@objc public protocol URLSessionRequestsDataSource: NSObjectProtocol {
    @objc func modifiedRequest(for request: URLRequest) -> URLRequest
}
