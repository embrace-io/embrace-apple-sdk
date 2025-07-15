//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCaptureService
import EmbraceCommonInternal
@_implementationOnly import EmbraceObjCUtilsInternal
#endif

typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void
typealias DownloadTaskCompletion = (URL?, URLResponse?, Error?) -> Void

protocol URLSessionSwizzler: Swizzlable {
    init(handler: URLSessionTaskHandler, baseClass: AnyClass)
}

class EmbraceDummyURLSessionDelegate: NSObject, URLSessionDelegate {}

/// Service that generates OpenTelemetry spans for network requests that use `URLSession`.
@objc(EMBURLSessionCaptureService)
public final class URLSessionCaptureService: CaptureService, URLSessionTaskHandlerDataSource {

    public let options: URLSessionCaptureService.Options
    private let lock: NSLocking
    private let swizzlerProvider: URLSessionSwizzlerProvider
    private(set) var swizzlers: [any URLSessionSwizzler] = []
    private var handler: URLSessionTaskHandler?

    @objc public convenience init(options: URLSessionCaptureService.Options) {
        self.init(options: options, lock: NSLock(), swizzlerProvider: DefaultURLSessionSwizzlerProvider())
    }

    public convenience override init() {
        self.init(lock: NSLock(), swizzlerProvider: DefaultURLSessionSwizzlerProvider())
    }

    init(
        options: URLSessionCaptureService.Options = URLSessionCaptureService.Options(),
        lock: NSLocking,
        swizzlerProvider: URLSessionSwizzlerProvider
    ) {
        self.options = options
        self.lock = lock
        self.swizzlerProvider = swizzlerProvider
    }

    public override func onInstall() {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard state == .uninstalled else {
            return
        }

        handler = DefaultURLSessionTaskHandler(dataSource: self)
        guard let handler = handler else {
            return
        }

        swizzlers = swizzlerProvider.getAll(usingHandler: handler)
        swizzlers.forEach {
            do {
                try $0.install()
            } catch let exception {
                Embrace.logger.error("Capture service couldn't be installed: \(exception.localizedDescription)")
            }
        }
    }

    var injectTracingHeader: Bool {
        // check remote config
        guard Embrace.client?.config.isNetworkSpansForwardingEnabled == true else {
            return false
        }

        // check local config
        return options.injectTracingHeader
    }

    var requestsDataSource: URLSessionRequestsDataSource? {
        return options.requestsDataSource
    }

    var ignoredURLs: [String] {
        return options.ignoredURLs
    }
}

// swiftlint:disable line_length

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
                let proxiedDelegate = (delegate != nil) ? delegate : EmbraceDummyURLSessionDelegate()

                // check if we support proxying this type of delegate
                guard isDelegateSupported(proxiedDelegate) else {
                    return originalImplementation(urlSession, Self.selector, configuration, delegate, queue)
                }

                // Add protection against re-proxying our own proxy
                guard !(proxiedDelegate is EMBURLSessionDelegateProxy) else {
                    if let newDelegate = proxiedDelegate as? EMBURLSessionDelegateProxy,
                       let originalDelegate = newDelegate.originalDelegate as? URLSessionDelegate {
                        return originalImplementation(urlSession, Self.selector, configuration, originalDelegate, queue)
                    }
                    return originalImplementation(urlSession, Self.selector, configuration, delegate, queue)
                }

                let newDelegate = EMBURLSessionDelegateProxy(delegate: proxiedDelegate, handler: handler)
                let session = originalImplementation(urlSession, Self.selector, configuration, newDelegate, queue)

                // If we have already been swizzled by another player, we notify our proxied delegate,
                // as this will later help determine whether or not to forward the invocation of various
                // `URLSessionDelegate` methods.
                if session.delegate !== newDelegate {
                    newDelegate.swizzledDelegate = session.delegate
                }

                return session
            }
        }
    }

    // list of third party URLSessionDelegate implementations that we don't support
    // due to issues / crashes out of our control
    private let unsupportedDelegates: [String] = [

        // This type belongs to an internal library used by Firebase which
        // incorrectly assumes the type of the URLSession delegate, resulting
        // in it calling a method that is not implemented by our proxy.
        //
        // We can't solve this on our side in a clean way so we'll just not
        // capture any requests from this library until the issue is solved
        // on their side.
        //
        // Library: https://github.com/google/gtm-session-fetcher/
        // Issue: https://github.com/google/gtm-session-fetcher/issues/190
        "GTMSessionFetcher"
    ]

    func isDelegateSupported(_ delegate: AnyObject?) -> Bool {
        guard let delegate = delegate else {
            return true
        }

        let name = NSStringFromClass(type(of: delegate))
        return unsupportedDelegates.first { name.contains($0) } == nil
    }
}

struct SessionTaskResumeSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSessionTask, Selector) -> Void
    typealias BlockImplementationType = @convention(block) (URLSessionTask) -> Void
    static var selector: Selector = #selector(URLSessionTask.resume)

    var baseClass: AnyClass
    private let handler: URLSessionTaskHandler
    private var originalDelegate: URLSessionTaskDelegate?

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSessionTask.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        if #available(iOS 15.0, tvOS 15.0, macOS 12, watchOS 8, *) {
            try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
                return { [weak handler = self.handler] task in
                    let handled = handler?.create(task: task) ?? true

                    // if the task was handled by this swizzler
                    // by the time resume was called it probably means
                    // it was an async/await task
                    // we set a proxy delegate to get a callback when the task finishes
                    if handled, let handler = handler, task.state == .suspended {
                        let originalDelegate = task.delegate
                        task.delegate = EMBURLSessionDelegateProxy(delegate: originalDelegate, handler: handler)
                    }

                    // call original
                    originalImplementation(task, Self.selector)
                }
            }
        } else {
            // only supported in ios 15+
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
        try swizzleInstanceMethod { _ in
            return { urlSession, url -> URLSessionDataTask in
                // create the task using a URLRequest and let the other swizzler handle it
                return urlSession.dataTask(with: URLRequest(url: url))
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
        try swizzleInstanceMethod { _ in
            return { urlSession, url, completion -> URLSessionDataTask in
                // create the task using a URLRequest and let the other swizzler handle it
                return urlSession.dataTask(with: URLRequest(url: url)) { data, response, error in
                    completion?(data, response, error)
                }
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

                let request = urlRequest.addEmbraceHeaders()

                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, request, completion)
                    handler?.create(task: task)
                    return task
                }

                var originalTask: URLSessionDataTask?

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

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
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

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
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
                    if let task = originalTask {
                        handler?.finish(task: task, data: data, error: error)
                    }
                    completion(data, response, error)
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

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
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

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, url, completion -> URLSessionUploadTask in

                let request = urlRequest.addEmbraceHeaders()

                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, request, url, completion)
                    handler?.create(task: task)
                    return task
                }

                var originalTask: URLSessionUploadTask?
                let uploadTask = originalImplementation(urlSession, Self.selector, request, url) { data, response, error in
                    if let task = originalTask {
                        handler?.finish(task: task, data: data, error: error)
                    }
                    completion(data, response, error)
                }
                originalTask = uploadTask
                handler?.create(task: uploadTask)
                return uploadTask
            }
        }
    }
}

struct DownloadTaskWithURLRequestSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest) -> URLSessionDownloadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest) -> URLSessionDownloadTask

    static var selector: Selector = #selector(
        URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
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

struct DownloadTaskWithURLRequestWithCompletionSwizzler: URLSessionSwizzler {
    typealias ImplementationType = @convention(c) (URLSession, Selector, URLRequest, DownloadTaskCompletion?) -> URLSessionDownloadTask
    typealias BlockImplementationType = @convention(block) (URLSession, URLRequest, DownloadTaskCompletion?) -> URLSessionDownloadTask

    static var selector: Selector = #selector(
        URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping DownloadTaskCompletion) -> URLSessionDownloadTask
    )

    private let handler: URLSessionTaskHandler
    var baseClass: AnyClass

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
        self.handler = handler
        self.baseClass = baseClass
    }

    func install() throws {
        try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
            return { [weak handler = self.handler] urlSession, urlRequest, completion -> URLSessionDownloadTask in

                let request = urlRequest.addEmbraceHeaders()

                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, request, completion)
                    handler?.create(task: task)
                    return task
                }

                var originalTask: URLSessionDownloadTask?
                let downloadTask = originalImplementation(urlSession, Self.selector, request) { url, response, error in
                    if let task = originalTask {
                        var data: Data?
                        if let url = url, let dataFromURL = try? Data(contentsOf: url) {
                            data = dataFromURL
                        }
                        handler?.finish(task: task, data: data, error: error)
                    }
                    completion(url, response, error)
                }
                originalTask = downloadTask
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

    init(handler: URLSessionTaskHandler, baseClass: AnyClass = URLSession.self) {
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

// swiftlint:enable line_length
