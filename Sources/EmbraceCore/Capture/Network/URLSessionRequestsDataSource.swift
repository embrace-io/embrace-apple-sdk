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
///
/// The returned request is only used to populate the data of the network span;
/// the request that is actually sent is never modified.
///
/// Threading:
/// `modifiedRequest(for:)` is called synchronously on the thread that creates or resumes
/// the `URLSessionTask`, which can be any thread, including the main thread.
/// Implementations must be fast and must not block: avoid acquiring locks that the app
/// may hold while creating requests, calling `DispatchQueue.main.sync`, or waiting on semaphores.
///
/// Creating or resuming `URLSession` tasks from inside `modifiedRequest(for:)` is allowed,
/// but those tasks are also passed to this method. If your implementation makes its own requests,
/// add their URLs to `URLSessionCaptureService.Options.ignoredURLs`, or make sure a new
/// request is not started on every call. Otherwise the calls recurse indefinitely.
public protocol URLSessionRequestsDataSource: AnyObject {
    /// Returns the request whose data will be recorded in the network span.
    /// Called at most once per captured task.
    func modifiedRequest(for request: URLRequest) -> URLRequest
}
