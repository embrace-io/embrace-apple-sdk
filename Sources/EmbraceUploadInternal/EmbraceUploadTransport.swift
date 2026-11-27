//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A single network request created by an `EmbraceUploadTransport`.
package protocol EmbraceUploadTask: AnyObject {
    func resume()
    func cancel()
}

/// Sends the requests made by the upload operations.
///
/// `URLSession` is the transport used by the SDK. Other implementations let the
/// upload logic run without going through the network stack.
package protocol EmbraceUploadTransport: AnyObject {
    /// Creates a task that sends `request` once resumed and calls `completionHandler` when it finishes.
    func uploadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> EmbraceUploadTask
}

extension URLSessionDataTask: EmbraceUploadTask {}

extension URLSession: EmbraceUploadTransport {
    package func uploadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> EmbraceUploadTask {
        dataTask(with: request, completionHandler: completionHandler)
    }
}
