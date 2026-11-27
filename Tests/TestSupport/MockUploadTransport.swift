//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceUploadInternal
import Foundation

/// Upload transport that answers requests with the responses mocked in `EmbraceHTTPMock`,
/// without going through `URLSession`.
///
/// Works on every platform, including watchOS, where `URLSession` ignores custom
/// `URLProtocol` classes such as `EmbraceHTTPMock`.
package final class MockUploadTransport: EmbraceUploadTransport {

    private let queue = DispatchQueue(label: "com.embrace.test.mock_upload_transport", attributes: .concurrent)

    package init() {}

    package func uploadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> EmbraceUploadTask {
        MockUploadTask(request: request, queue: queue, completionHandler: completionHandler)
    }
}

/// Task created by `MockUploadTransport`. Calls its completion handler exactly once:
/// with the mocked result once resumed, or with `URLError.cancelled` when cancelled first.
final class MockUploadTask: EmbraceUploadTask, @unchecked Sendable {

    private let request: URLRequest
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var completionHandler: (@Sendable (Data?, URLResponse?, Error?) -> Void)?

    init(request: URLRequest, queue: DispatchQueue, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
        self.request = request
        self.queue = queue
        self.completionHandler = completionHandler
    }

    func resume() {
        queue.async { [self] in
            guard let url = request.url else {
                finish(nil, nil, URLError(.badURL))
                return
            }

            let (data, response, error) = EmbraceHTTPMock.respond(to: request, url: url)
            finish(data, response, error)
        }
    }

    func cancel() {
        finish(nil, nil, URLError(.cancelled))
    }

    private func finish(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        let handler = lock.withLock {
            defer { completionHandler = nil }
            return completionHandler
        }
        handler?(data, response, error)
    }
}
