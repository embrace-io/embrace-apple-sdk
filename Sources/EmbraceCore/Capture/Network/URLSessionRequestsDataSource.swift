//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Decides the parent of the network span created for a request.
public enum EmbraceNetworkSpanParent {
    /// The network span starts a new trace, regardless of the network span parent set through
    /// `EmbraceIO.setNetworkSpanParent` and of any `traceparent` header on the request.
    case noParent

    /// The network span is parented to the span with the given context.
    /// A context whose identifiers can't refer to a span is ignored with a warning, as if `default` was returned.
    case parent(EmbraceSpanContext)

    /// No decision for this request. The network span is parented to the span named in the request's
    /// `traceparent` header if it has a well-formed one, otherwise to the network span parent set through
    /// `EmbraceIO.setNetworkSpanParent`, if any. Otherwise it starts a new trace.
    case `default`
}

/// This protocol can be used to modify requests before the Embrace SDK
/// captures their data into OTel spans, and to choose the parent of each network span.
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
///
/// `spanParent(for:currentParentContext:)` follows the same threading rules.
public protocol URLSessionRequestsDataSource: AnyObject {
    /// Returns the request whose data will be recorded in the network span.
    /// Its `traceparent` header, if any, is the one used to choose the network span's parent.
    /// Called at most once per captured task.
    func modifiedRequest(for request: URLRequest) -> URLRequest

    /// Returns the parent of the network span created for the given request.
    ///
    /// Called at most once per captured task, after `modifiedRequest(for:)` and before the network span
    /// starts. It isn't called for requests that aren't captured, such as those matching
    /// `URLSessionCaptureService.Options.ignoredURLs`.
    ///
    /// Calls that take longer than a few milliseconds are logged as a warning.
    ///
    /// - Parameters:
    ///   - request: The request returned by `modifiedRequest(for:)`.
    ///   - currentParentContext: The context of the network span parent set through
    ///     `EmbraceIO.setNetworkSpanParent`, if any.
    /// - Returns: The parent decision. The default implementation returns `.default`.
    func spanParent(for request: URLRequest, currentParentContext: EmbraceSpanContext?) -> EmbraceNetworkSpanParent
}

extension URLSessionRequestsDataSource {
    public func spanParent(for request: URLRequest, currentParentContext: EmbraceSpanContext?) -> EmbraceNetworkSpanParent {
        return .default
    }
}
