//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

public protocol EmbraceLogUploader: AnyObject {
    func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?)
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
            guard let self = self else { return }
            do {
                // clear data from cache that shouldn't be retried as it's stale
                self.clearCacheFromStaleData()
                
                // get all the data cached first, is the only thing that could throw
                let cachedObjects = try self.cache.fetchAllUploadData()

                // in place mechanism to not retry sending cache data at the same time 
                guard !self.isRetryingCache else {
                    return
                }

                self.isRetryingCache = true
                defer {
                    // on finishing everything, allow to retry cache (i.e. reconnection)
                    self.isRetryingCache = false
                }

                // create a sempahore to allow only to send two request at a time so we don't
                // get throttled by the backend on cases where cache has many failed requests.

                for uploadData in cachedObjects {
                    guard let type = EmbraceUploadType(rawValue: uploadData.type) else {
                        continue
                    }
                    self.semaphore.wait()

                    self.reUploadData(
                        id: uploadData.id,
                        data: uploadData.data,
                        type: type,
                        attemptCount: uploadData.attemptCount
                    ) {
                        self.semaphore.signal()
                    }
                }
            } catch {
                self.logger.debug("Error retrying cached upload data: \(error.localizedDescription)")
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

    // MARK: - Internal
    private func uploadData(
        id: String,
        data: Data,
        type: EmbraceUploadType,
        attemptCount: Int = 0,
        retryCount: Int? = nil,
        completion: ((Result<(), Error>) -> Void)?) {

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
            do {
                try self?.cache.saveUploadData(id: id, type: type, data: data)
                    completion?(.success(()))
            } catch {
                self?.logger.debug("Error caching upload data: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }

        // upload operation
        let uploadOperation = EmbraceUploadOperation(
            urlSession: urlSession,
            queue: queue,
            metadataOptions: options.metadata,
            endpoint: endpoint(for: type),
            identifier: id,
            data: data,
            retryCount: retryCount ?? options.redundancy.automaticRetryCount,
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
                    do {
                        try self?.cache.updateAttemptCount(id: id, type: type, attemptCount: attemptCount)
                    } catch {
                        self?.logger.debug("Error updating cache: \(error.localizedDescription)")
                    }
                }
                return
            }

            addDeleteUploadDataOperation(id: id, type: type)
        }
    }

    private func addDeleteUploadDataOperation(id: String, type: EmbraceUploadType) {
        operationQueue.addOperation { [weak self] in
            do {
                try self?.cache.deleteUploadData(id: id, type: type)
            } catch {
                self?.logger.debug("Error deleting cache: \(error.localizedDescription)")
            }
        }

    }

    private func clearCacheFromStaleData() {
        operationQueue.addOperation { [weak self] in
            do {
                try self?.cache.clearStaleDataIfNeeded()
            } catch {
                self?.logger.debug("Error clearing stale date from cache: \(error.localizedDescription)")
            }
        }
    }

    private func endpoint(for type: EmbraceUploadType) -> URL {
        switch type {
        case .spans: return options.endpoints.spansURL
        case .log: return options.endpoints.logsURL
        }
    }
}
