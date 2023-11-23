//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void
typealias DownloadTaskCompletion = (URL?, URLResponse?, Error?) -> Void

protocol URLSessionSwizzler: Swizzlable {
    init(handler: URLSessionTaskHandler, baseClass: AnyClass)
    func install() throws
}

public final class URLSessionCollector: InstalledCollector {
    private let lock: NSLock
    private let swizzlers: [any URLSessionSwizzler]
    private let handler: URLSessionTaskHandler
    private(set) var status: CollectorState = .uninstalled {
        didSet {
            handler.changedState(to: status)
        }
    }

    public convenience init() {
        self.init(lock: NSLock(), handler: DefaultURLSessionTaskHandler())
    }

    init(lock: NSLock = NSLock(),
         handler: URLSessionTaskHandler = DefaultURLSessionTaskHandler()) {
        self.lock = lock
        self.handler = handler
        self.swizzlers = URLSessionCollector.defaultSwizzlers(handler: handler)
    }

    public func install() {
        lock.lock()
        defer {
            status = .installed
            lock.unlock()
        }
        swizzlers.forEach {
            do {
                try $0.install()
            } catch let exception {
                // TODO: See what to do when this kind of issues arises
                ConsoleLog.error("Collector couldn't be installed: \(exception.localizedDescription)")
            }
        }
    }

    public func shutdown() {
        status = .uninstalled
    }

    public func start() {
        status = .listening
    }

    public func stop() {
        status = .paused
    }

    public func isAvailable() -> Bool { true }
}

// MARK: - Static Methods
private extension URLSessionCollector {
    static func defaultSwizzlers(handler: URLSessionTaskHandler) -> [any URLSessionSwizzler] {
        let urlSessionLocalType: AnyClass = type(of: URLSession.shared)
        let swizzlingTypes: [any URLSessionSwizzler.Type] = [
            // Data Tasks
            DataTaskWithURLSwizzler.self,
            DataTaskWithURLRequestSwizzler.self,
            DataTaskWithURLAndCompletionSwizzler.self,
            DataTaskWithURLRequestAndCompletionSwizzler.self,

            // Upload Tasks
            UploadTaskWithRequestFromDataSwizzler.self,
            UploadTaskWithRequestFromDataWithCompletionSwizzler.self,
            UploadTaskWithRequestFromFileSwizzler.self,
            UploadTaskWithRequestFromFileWithCompletionSwizzler.self,

            // Download Tasks
            DownloadTaskWithURLSwizzler.self,
            DownloadTaskWithURLWithCompletionSwizzler.self,

            // Upload Streaming Tasks
            UploadTaskWithStreamedRequestSwizzler.self
        ]
        var swizzlers: [any URLSessionSwizzler] = []

        for swizzlingType in swizzlingTypes {
            swizzlers.append(swizzlingType.init(handler: handler, baseClass: URLSession.self))
            if !hasTheSameImplementation(for: swizzlingType.selector, lhs: urlSessionLocalType, rhs: URLSession.self) {
                swizzlers.append(swizzlingType.init(handler: handler, baseClass: urlSessionLocalType))
            }
        }

        swizzlers.append(URLSessionInitWithDelegateSwizzler(handler: handler))
        return swizzlers
    }

    /// Compares two `AnyClass` (the old objc `Class`) to see if the implementation (pointer) for a selector is the same or not.
    ///
    /// This method is necessary because there're some classes where a class, and a subclass might implement methods
    /// in a different way. For example, `URLSession` implementation of some methods might differ from the implementation
    /// of some methods of `URLSession.shared` (aka. `__URLSessionLocal`). In those cases we have to know if the method
    /// implementation differs to be sure what are we going to swizzle.
    ///
    /// - Parameters:
    ///   - selector: The selector to compare the implementations for.
    ///   - lhs: The first class to compare.
    ///   - rhs: The second class to compare.
    /// - Returns: `true` if the implementations of the specified selector are the same in both classes; `false` otherwise.
    static func hasTheSameImplementation(for selector: Selector, lhs: AnyClass, rhs: AnyClass) -> Bool {
        guard let leftImplementation = class_getMethodImplementation(lhs, selector) else { return false }
        guard let rightImplementation = class_getMethodImplementation(rhs, selector) else { return false }
        return leftImplementation == rightImplementation
    }
}

struct URLSessionInitWithDelegateSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLSessionConfiguration, URLSessionDelegate?, OperationQueue?) -> URLSession
    typealias BlockImplementationType = @convention(block) (URLSession, URLSessionConfiguration, URLSessionDelegate?, OperationQueue?) -> URLSession
    static var selector: Selector = #selector(
        URLSession.init(configuration:delegate:delegateQueue:)
    )
    var baseClass: AnyClass
    private let handler: URLSessionTaskHandler

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleClassMethod { originalImplementation -> BlockImplementationType in
            return { urlSession, configuration, delegate, queue -> URLSession in
                guard let delegate = delegate else {
                    return originalImplementation(urlSession,
                                                  Self.selector,
                                                  configuration,
                                                  delegate,
                                                  queue)
                }
                let newDelegate = URLSessionDelegateProxy(originalDelegate: delegate, handler: handler)
                let session = originalImplementation(urlSession, Self.selector, configuration, newDelegate, queue)
                return session
            }
        }
    }
}

struct DataTaskWithURLSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URL) -> URLSessionDataTask
    typealias BlockImplementationType = @convention(block) (URLSession, URL) -> URLSessionDataTask

    static var selector: Selector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask)
    var baseClass: AnyClass

    private let handler: URLSessionTaskHandler

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation in
            return { [weak handler = self.handler] urlSession, url -> URLSessionDataTask in
                // TODO: For this cases, we'll need to have the `URLSessionDelegate` swizzled/proxied.
                // Note: two things to take into account:
                // 1. We cannot ensure that this request will be tracked with this implementation.
                //  For example, when using `URLSession.shared.dataTask(with:)`.
                // 2. As this is has `URL` as parameter, and not `URLRequest`, we cannot add custom headers.
                //  The old sdk would call the original method using `URLRequest`, but that leads to other kind
                //  of edge cases.
                let dataTask = originalImplementation(urlSession, Self.selector, url)
                handler?.create(task: dataTask)
                return dataTask
            }
        }
    }
}

struct DataTaskWithURLRequestSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest) -> URLSessionDataTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest) -> URLSessionDataTask
    static var selector: Selector = #selector(
        URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask
    )
    var baseClass: AnyClass
    private let handler: URLSessionTaskHandler

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest -> URLSessionDataTask in
                let request = urlRequest.addEmbraceHeaders()
                // TODO: For this cases, we'll need to have the `URLSessionDelegate` swizzled/proxied.
                let dataTask = originalImplementation(urlSession, Self.selector, request)
                handler?.create(task: dataTask)
                return dataTask
            }
        }
    }
}

struct DataTaskWithURLAndCompletionSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URL, URLSessionCompletion?) -> URLSessionDataTask
    typealias BlockImplementationType = @convention(block) (URLSession, URL, URLSessionCompletion?) -> URLSessionDataTask
    static var selector: Selector = #selector(
        URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping URLSessionCompletion) -> URLSessionDataTask
    )
    var baseClass: AnyClass

    private let handler: URLSessionTaskHandler

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, url, completion -> URLSessionDataTask in
                // TODO: For this cases, we'll need to have the `URLSessionDelegate` swizzled/proxied.
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, url, completion)
                    handler?.create(task: task)
                    return task
                }

                var originalTask: URLSessionDataTask?

                let dataTask = originalImplementation(urlSession, Self.selector, url) { data, response, error in
                    if let task = originalTask {
                        handler?.finish(task: task, data: data, error: error)
                    }
                    completion(data, response, error)
                }

                originalTask = dataTask
                handler?.create(task: dataTask)
                return dataTask
            }
        }
    }
}

struct DataTaskWithURLRequestAndCompletionSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URLSessionCompletion?) -> URLSessionDataTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URLSessionCompletion?) -> URLSessionDataTask

    static var selector: Selector = #selector(
        URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping URLSessionCompletion) -> URLSessionDataTask
    )

    var baseClass: AnyClass

    private let handler: URLSessionTaskHandler

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, completion -> URLSessionDataTask in
                // TODO: For this cases, we'll need to have the `URLSessionDelegate` swizzled/proxied.
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, urlRequest, completion)
                    handler?.create(task: task)
                    return task
                }

                var originalTask: URLSessionDataTask?
                let request = urlRequest.addEmbraceHeaders()
                let dataTask = originalImplementation(urlSession, Self.selector, request) { data, response, error in
                    if let task = originalTask {
                        handler?.finish(task: task, data: data, error: error)
                    }
                    completion(data, response, error)
                }
                originalTask = dataTask
                handler?.create(task: dataTask)
                return dataTask
            }
        }
    }
}

struct UploadTaskWithRequestFromDataSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, Data) -> URLSessionUploadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, Data) -> URLSessionUploadTask
    static var selector: Selector = #selector(
        URLSession.uploadTask(with:from:) as (URLSession) -> (URLRequest, Data) -> URLSessionUploadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, data -> URLSessionUploadTask in
                let request = urlRequest.addEmbraceHeaders()
                let dataTask = originalImplementation(urlSession, Self.selector, request, data)
                handler?.create(task: dataTask)
                return dataTask
            }
        }
    }
}

struct UploadTaskWithRequestFromDataWithCompletionSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, Data?, URLSessionCompletion?) -> URLSessionUploadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, Data?, URLSessionCompletion?) -> URLSessionUploadTask

    static var selector: Selector = #selector(
        URLSession.uploadTask(with:from:completionHandler:) as (URLSession) -> (URLRequest, Data?, @escaping URLSessionCompletion) -> URLSessionUploadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, uploadData, completion -> URLSessionUploadTask in
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, urlRequest, uploadData, completion)
                    handler?.create(task: task)
                    return task
                }

                let request = urlRequest.addEmbraceHeaders()
                var originalTask: URLSessionUploadTask?
                let uploadTask = originalImplementation(urlSession, Self.selector, request, uploadData) { data, response, error in
                    completion(data, response, error)
                    guard let task = originalTask else { return }
                    handler?.finish(task: task, data: data, error: error)
                }

                originalTask = uploadTask
                handler?.create(task: uploadTask)
                return uploadTask
            }
        }
    }
}

struct UploadTaskWithRequestFromFileSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URL) -> URLSessionUploadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URL) -> URLSessionUploadTask

    static var selector: Selector = #selector(
        URLSession.uploadTask(with:fromFile:) as (URLSession) -> (URLRequest, URL) -> URLSessionUploadTask
    )
    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, url -> URLSessionUploadTask in
                let request = urlRequest.addEmbraceHeaders()
                let uploadTask = originalImplementation(urlSession, Self.selector, request, url)
                handler?.create(task: uploadTask)
                return uploadTask
            }
        }
    }
}

struct UploadTaskWithRequestFromFileWithCompletionSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, URL, URLSessionCompletion?) -> URLSessionUploadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, URL, URLSessionCompletion?) -> URLSessionUploadTask

    static var selector: Selector = #selector(
        URLSession.uploadTask(with:fromFile:completionHandler:) as (URLSession) -> (URLRequest, URL, @escaping URLSessionCompletion) -> URLSessionUploadTask
    )
    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, url, completion -> URLSessionUploadTask in
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, urlRequest, url, completion)
                    handler?.create(task: task)
                    return task
                }

                let request = urlRequest.addEmbraceHeaders()
                var originalTask: URLSessionUploadTask?
                let uploadTask = originalImplementation(urlSession, Self.selector, request, url) { data, response, error in
                    completion(data, response, error)
                    guard let task = originalTask else { return }
                    handler?.finish(task: task, data: data, error: error)
                }
                originalTask = uploadTask
                handler?.create(task: uploadTask)
                return uploadTask
            }
        }
    }
}

struct DownloadTaskWithURLSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest) -> URLSessionDownloadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest) -> URLSessionDownloadTask

    static var selector: Selector = #selector(
        URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest -> URLSessionDownloadTask in
                let request = urlRequest.addEmbraceHeaders()
                let downloadTask = originalImplementation(urlSession, Self.selector, request)
                handler?.create(task: downloadTask)
                return downloadTask
            }
        }
    }
}

struct DownloadTaskWithURLWithCompletionSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, DownloadTaskCompletion?) -> URLSessionDownloadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, DownloadTaskCompletion?) -> URLSessionDownloadTask

    static var selector: Selector = #selector(
        URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping DownloadTaskCompletion) -> URLSessionDownloadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, completion -> URLSessionDownloadTask in
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, urlRequest, completion)
                    handler?.create(task: task)
                    return task
                }

                let request = urlRequest.addEmbraceHeaders()

                var originalTask: URLSessionDownloadTask?
                let downloadTask = originalImplementation(urlSession, Self.selector, request) { url, response, error in
                    completion(url, response, error)
                    guard let task = originalTask else { return }
                    var data: Data?
                    if let url = url, let dataFromURL = try? Data(contentsOf: url) {
                        data = dataFromURL
                    }

                    handler?.finish(task: task, data: data, error: error)
                }
                handler?.create(task: downloadTask)
                return downloadTask
            }
        }
    }
}

struct UploadTaskWithStreamedRequestSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest) -> URLSessionUploadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest) -> URLSessionUploadTask

    static var selector: Selector = #selector(
        URLSession.uploadTask(withStreamedRequest:) as (URLSession) -> (URLRequest) -> URLSessionUploadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest -> URLSessionUploadTask in
                let request = urlRequest.addEmbraceHeaders()
                let uploadTask = originalImplementation(urlSession, UploadTaskWithStreamedRequestSwizzler.selector, request)
                handler?.create(task: uploadTask)
                return uploadTask
            }
        }
    }
}
