//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

public protocol EmbraceLogUploader: AnyObject {
    func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?)
    func uploadAttachment(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?)
}

/// Class in charge of uploading all the data collected by the Embrace SDK.
public class EmbraceUpload: EmbraceLogUploader {

    public private(set) var options: Options
    public private(set) var logger: InternalLogger
    public private(set) var queue: DispatchQueue

    @ThreadSafe
    private(set) var isRetryingCache: Bool = false

    private let urlSession: URLSession
    let cache: EmbraceUploadCache
    let operationQueue: OperationQueue
    let semaphore: DispatchSemaphore
    private var reachabilityMonitor: EmbraceReachabilityMonitor?

    /// Returns an `EmbraceUpload` instance
    /// - Parameters:
    ///   - options: `EmbraceUpload.Options` instance
    ///   - logger: `EmbraceConsoleLogger` instance
    ///   - queue: `DispatchQueue` to be used for all upload operations
    public init(
        options: Options,
        logger: InternalLogger,
        queue: DispatchQueue,
        semaphore: DispatchSemaphore = .init(value: 2)
    ) throws {

        self.options = options
        self.logger = logger
        self.queue = queue
        self.semaphore = semaphore

        cache = try EmbraceUploadCache(options: options.cache, logger: logger)

        urlSession = URLSession(configuration: options.urlSessionConfiguration)

        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = queue

        // reachability monitor
        if options.redundancy.retryOnInternetConnected {
            let monitorQueue = DispatchQueue(label: "com.embrace.upload.reachability")
            reachabilityMonitor = EmbraceReachabilityMonitor(queue: monitorQueue)
            reachabilityMonitor?.onConnectionRegained = { [weak self] in
                self?.retryCachedData()
            }

            reachabilityMonitor?.start()
        }
    }

    /// Attempts to upload all the available cached data.
    public func retryCachedData() {
        queue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            // in place mechanism to not retry sending cache data at the same time
            guard !strongSelf.isRetryingCache else {
                return
            }

            strongSelf.isRetryingCache = true

            defer {
                // on finishing everything, allow to retry cache (i.e. reconnection)
                strongSelf.isRetryingCache = false
            }

            // clear data from cache that shouldn't be retried as it's stale
            strongSelf.clearCacheFromStaleData()

            // get all the data cached first, is the only thing that could throw
            let cachedObjects = strongSelf.cache.fetchAllUploadData()

            // create a sempahore to allow only to send two request at a time so we don't
            // get throttled by the backend on cases where cache has many failed requests.

            for uploadData in cachedObjects {
                guard let type = EmbraceUploadType(rawValue: uploadData.type) else {
                    continue
                }
                strongSelf.semaphore.wait()

                strongSelf.reUploadData(
                    id: uploadData.id,
                    data: uploadData.data,
                    type: type,
                    attemptCount: uploadData.attemptCount
                ) {
                    strongSelf.semaphore.signal()
                }
            }
        }
    }

    /// Uploads the given session span data
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - data: Data of the session's payload
    ///   - completion: Completion block called when the data is successfully cached, or when an `Error` occurs
    public func uploadSpans(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(
                id: id,
                data: data,
                type: .spans,
                completion: completion
            )
        }
    }

    /// Uploads the given log data
    /// - Parameters:
    ///   - id: Identifier of the log batch (has no utility aside of caching)
    ///   - data: Data of the log's payload
    ///   - completion: Completion block called when the data is successfully cached, or when an `Error` occurs
    public func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(
                id: id,
                data: data,
                type: .log,
                completion: completion
            )
        }
    }

    /// Uploads the given attachment data
    /// - Parameters:
    ///   - id: Identifier of the attachment
    ///   - data: The attachment's data
    ///   - completion: Completion block called when the data is successfully uploaded, or when an `Error` occurs
    public func uploadAttachment(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(
                id: id,
                data: data,
                type: .attachment,
                completion: completion
            )
        }
    }

    // MARK: - Internal
    private func uploadData(
        id: String,
        data: Data,
        type: EmbraceUploadType,
        attemptCount: Int = 0,
        completion: ((Result<(), Error>) -> Void)?
    ) {

        // validate identifier
        guard id.isEmpty == false else {
            completion?(.failure(EmbraceUploadError.internalError(.invalidMetadata)))
            return
        }

        // validate data
        guard data.isEmpty == false else {
            completion?(.failure(EmbraceUploadError.internalError(.invalidData)))
            return
        }

        // cache operation
        let cacheOperation = BlockOperation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            if strongSelf.cache.saveUploadData(id: id, type: type, data: data) {
                completion?(.success(()))
            } else {
                strongSelf.logger.debug("Error caching upload data!")

                let error = NSError(domain: "com.embrace.upload", code: 5000)
                completion?(.failure(error))
            }
        }

        // upload operation
        let uploadOperation = createUploadOperation(
            id: id,
            type: type,
            urlSession: urlSession,
            data: data,
            retryCount: options.redundancy.automaticRetryCount,
            attemptCount: attemptCount) { [weak self] (result, attemptCount) in

            self?.queue.async { [weak self] in

                self?.handleOperationFinished(
                    id: id,
                    type: type,
                    result: result,
                    attemptCount: attemptCount
                )

                self?.clearCacheFromStaleData()
            }
        }

        // queue operations
        uploadOperation.addDependency(cacheOperation)
        operationQueue.addOperation(cacheOperation)
        operationQueue.addOperation(uploadOperation)
    }

    func reUploadData(id: String,
                      data: Data,
                      type: EmbraceUploadType,
                      attemptCount: Int,
                      completion: @escaping (() -> Void)) {
        let totalPendingRetries = options.redundancy.maximumAmountOfRetries - attemptCount
        let retries = min(options.redundancy.automaticRetryCount, totalPendingRetries)

        let uploadOperation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: options.metadata,
            endpoint: endpoint(for: type),
            identifier: id,
            data: data,
            retryCount: retries,
            exponentialBackoffBehavior: options.redundancy.exponentialBackoffBehavior,
            attemptCount: attemptCount,
            logger: logger) { [weak self] (result, attemptCount) in
                self?.queue.async { [weak self] in
                    self?.handleOperationFinished(
                        id: id,
                        type: type,
                        result: result,
                        attemptCount: attemptCount
                    )
                    completion()
                }
            }
        operationQueue.addOperation(uploadOperation)
    }

    private func createUploadOperation(
        id: String,
        type: EmbraceUploadType,
        urlSession: URLSession,
        data: Data,
        retryCount: Int,
        attemptCount: Int,
        completion: @escaping EmbraceUploadOperationCompletion
    ) -> EmbraceUploadOperation {

        if type == .attachment {
            return EmbraceAttachmentUploadOperation(
                urlSession: urlSession,
                queue: queue,
                metadataOptions: options.metadata,
                endpoint: endpoint(for: type),
                identifier: id,
                data: data,
                retryCount: retryCount,
                exponentialBackoffBehavior: options.redundancy.exponentialBackoffBehavior,
                attemptCount: attemptCount,
                logger: logger,
                completion: completion
            )
        }

        return EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: options.metadata,
            endpoint: endpoint(for: type),
            identifier: id,
            data: data,
            retryCount: retryCount,
            exponentialBackoffBehavior: options.redundancy.exponentialBackoffBehavior,
            attemptCount: attemptCount,
            logger: logger,
            completion: completion
        )
    }

    private func handleOperationFinished(
        id: String,
        type: EmbraceUploadType,
        result: EmbraceUploadOperationResult,
        attemptCount: Int
    ) {
        switch result {
        case .success:
            addDeleteUploadDataOperation(id: id, type: type)
        case .failure(let isRetriable):
            if isRetriable, attemptCount < options.redundancy.maximumAmountOfRetries {
                operationQueue.addOperation { [weak self] in
                    self?.cache.updateAttemptCount(id: id, type: type, attemptCount: attemptCount)
                }
                return
            }

            addDeleteUploadDataOperation(id: id, type: type)
        }
    }

    private func addDeleteUploadDataOperation(id: String, type: EmbraceUploadType) {
        operationQueue.addOperation { [weak self] in
            self?.cache.deleteUploadData(id: id, type: type)
        }
    }

    private func clearCacheFromStaleData() {
        operationQueue.addOperation { [weak self] in
            self?.cache.clearStaleDataIfNeeded()
        }
    }

    private func endpoint(for type: EmbraceUploadType) -> URL {
        switch type {
        case .spans: return options.endpoints.spansURL
        case .log: return options.endpoints.logsURL
        case .attachment: return options.endpoints.attachmentsURL
        }
    }
}
