//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCaptureService
import EmbraceCommon

/*
 We decided that, to improve readability, we'll keep all the classes that swizzle methods
 from `URLSession` together. That's why we've disabled the file_length warning in this case.
 */

typealias URLSessionCompletion = (Data?, URLResponse?, Error?) -> Void
typealias DownloadTaskCompletion = (URL?, URLResponse?, Error?) -> Void

protocol URLSessionSwizzler: Swizzlable {
    init(handler: URLSessionTaskHandler, baseClass: AnyClass)
    func install() throws
}

@objc public final class URLSessionCaptureService: CaptureService, URLSessionTaskHandlerDataSource {

    private let lock: NSLocking
    private let swizzlerProvider: URLSessionSwizzlerProvider
    private var swizzlers: [any URLSessionSwizzler] = []
    private var handler: URLSessionTaskHandler?

    public convenience override init() {
        self.init(lock: NSLock(), swizzlerProvider: DefaultURLSessionSwizzlerProvider())
    }

    init(lock: NSLocking, swizzlerProvider: URLSessionSwizzlerProvider) {
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
                // TODO: See what to do when this kind of issues arises
                ConsoleLog.error("Capture service couldn't be installed: \(exception.localizedDescription)")
            }
        }
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
                let newDelegate = URLSessionDelegateProxy(originalDelegate: proxiedDelegate, handler: handler)
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
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, urlRequest, url, completion)
                    handler?.create(task: task)
                    return task
                }

                let request = urlRequest.addEmbraceHeaders()
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
                guard let completion = completion else {
                    let task = originalImplementation(urlSession, Self.selector, urlRequest, completion)
                    handler?.create(task: task)
                    return task
                }

                let request = urlRequest.addEmbraceHeaders()

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
