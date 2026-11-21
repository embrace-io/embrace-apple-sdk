//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceCore

/// A `URLSession` whose task methods return unstarted tasks and keep the completion handler: one
/// slot for the latest data or upload task, one for the latest download task. A test calls that
/// handler with `completeDataTask` or `completeDownloadTask` and asserts right after, with no network
/// round trip to wait for.
///
/// - Install the swizzler under test with `baseClass: StubURLSession.self`, and check the selector
///   with `assertOverrides`. `swizzleInstanceMethod` patches the method that
///   `class_getInstanceMethod` finds, which for a method this class doesn't override is
///   `URLSession`'s own, so the swizzle would apply to every session in the process.
/// - The overrides are `dynamic`, so calls go through `objc_msgSend` and reach the swizzled method
///   whatever the static type of the reference.
/// - Create it with `StubURLSession.make()`. `URLSession(configuration:)` comes from a class factory
///   that returns `URLSession` rather than `instancetype`, so subclasses don't inherit it, and the
///   inherited `init()` is deprecated. `make()` calls `init()` through a protocol requirement, which
///   Swift doesn't check for deprecation, so creating the stub adds no warning.
final class StubURLSession: URLSession, @unchecked Sendable {
    /// Creates the returned tasks. Don't resume them: they belong to a real session, so resuming sends
    /// a request whose result never reaches the stored completion.
    private static let taskFactory = URLSession(configuration: .ephemeral)

    private let lock = NSLock()
    private var dataCompletion: URLSessionCompletion?
    private var downloadCompletion: DownloadTaskCompletion?

    static func make() -> StubURLSession {
        construct(StubURLSession.self)
    }

    private static func construct<T: DefaultInitializable>(_: T.Type) -> T {
        T()
    }

    /// Fails the test unless this class overrides `selector`, so a swizzler installed on it can't
    /// patch `URLSession` itself.
    static func assertOverrides(_ selector: Selector, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(
            class_getInstanceMethod(StubURLSession.self, selector),
            class_getInstanceMethod(URLSession.self, selector),
            "StubURLSession doesn't override \(selector)",
            file: file,
            line: line
        )
    }

    /// Calls the latest data or upload task's completion synchronously on the calling thread, and
    /// clears it. Fails the test if there's no completion to call.
    func completeDataTask(
        data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line
    ) {
        let completion = lock.withLock {
            defer { dataCompletion = nil }
            return dataCompletion
        }
        guard let completion else {
            XCTFail("No data or upload task completion to call", file: file, line: line)
            return
        }
        completion(data, response, error)
    }

    /// Calls the latest download task's completion synchronously on the calling thread, and clears
    /// it. Fails the test if there's no completion to call.
    func completeDownloadTask(
        location: URL?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line
    ) {
        let completion = lock.withLock {
            defer { downloadCompletion = nil }
            return downloadCompletion
        }
        guard let completion else {
            XCTFail("No download task completion to call", file: file, line: line)
            return
        }
        completion(location, response, error)
    }

    @objc dynamic override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        lock.withLock { dataCompletion = completionHandler }
        return Self.taskFactory.dataTask(with: request)
    }

    @objc dynamic override func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        lock.withLock { dataCompletion = completionHandler }
        return Self.taskFactory.dataTask(with: url)
    }

    @objc dynamic override func uploadTask(
        with request: URLRequest,
        from bodyData: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        lock.withLock { dataCompletion = completionHandler }
        return Self.taskFactory.uploadTask(with: request, from: bodyData ?? Data())
    }

    @objc dynamic override func uploadTask(
        with request: URLRequest,
        fromFile fileURL: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        lock.withLock { dataCompletion = completionHandler }
        return Self.taskFactory.uploadTask(with: request, fromFile: fileURL)
    }

    @objc dynamic override func downloadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        lock.withLock { downloadCompletion = completionHandler }
        return Self.taskFactory.downloadTask(with: request)
    }
}

private protocol DefaultInitializable {
    init()
}

extension StubURLSession: DefaultInitializable {}
