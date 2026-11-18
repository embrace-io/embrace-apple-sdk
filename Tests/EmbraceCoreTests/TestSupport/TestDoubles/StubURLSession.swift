//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceCore

/// A `URLSession` that returns unstarted tasks and keeps the completion handler of the last task it
/// created, so a test can call that completion itself and assert right after, with no network round
/// trip to wait for.
///
/// - Install the swizzler under test with `baseClass: StubURLSession.self`. Every method a swizzler
///   replaces must be overridden here: `swizzleInstanceMethod` patches the method that
///   `class_getInstanceMethod` finds, which for a method this class doesn't override is
///   `URLSession`'s own.
/// - Call the session through a `URLSession`-typed reference. With `StubURLSession` as the static
///   type, Swift calls the override directly instead of sending an Objective-C message, and the
///   swizzled implementation never runs.
/// - Create it with `StubURLSession()`. That initializer is deprecated, but
///   `URLSession(configuration:)` isn't available to subclasses.
final class StubURLSession: URLSession, @unchecked Sendable {
    private let lock = NSLock()
    private var dataCompletion: URLSessionCompletion?
    private var downloadCompletion: DownloadTaskCompletion?

    /// Creates the returned tasks. They are never resumed.
    private let taskFactory = URLSession(configuration: .ephemeral)

    /// Calls the completion of the last data or upload task, as `URLSession` would when it finishes.
    func completeDataTask(data: Data?, response: URLResponse?, error: Error?) {
        let completion = lock.withLock { dataCompletion }
        completion?(data, response, error)
    }

    /// Calls the completion of the last download task, as `URLSession` would when it finishes.
    func completeDownloadTask(location: URL?, response: URLResponse?, error: Error?) {
        let completion = lock.withLock { downloadCompletion }
        completion?(location, response, error)
    }

    @objc dynamic override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        lock.withLock { dataCompletion = completionHandler }
        return taskFactory.dataTask(with: request)
    }

    @objc dynamic override func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        lock.withLock { dataCompletion = completionHandler }
        return taskFactory.dataTask(with: url)
    }

    @objc dynamic override func uploadTask(
        with request: URLRequest,
        from bodyData: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        lock.withLock { dataCompletion = completionHandler }
        return taskFactory.uploadTask(with: request, from: bodyData ?? Data())
    }

    @objc dynamic override func uploadTask(
        with request: URLRequest,
        fromFile fileURL: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        lock.withLock { dataCompletion = completionHandler }
        return taskFactory.uploadTask(with: request, fromFile: fileURL)
    }

    @objc dynamic override func downloadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        lock.withLock { downloadCompletion = completionHandler }
        return taskFactory.downloadTask(with: request)
    }
}
