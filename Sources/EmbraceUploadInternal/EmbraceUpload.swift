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

    private let cache: EmbraceUploadCache
    private let urlSession: URLSession
    private let operationQueue: OperationQueue
    private var reachabilityMonitor: EmbraceReachabilityMonitor?

    /// Returns an `EmbraceUpload` instance
    /// - Parameters:
    ///   - options: `EmbraceUpload.Options` instance
    ///   - logger: `EmbraceConsoleLogger` instance
    ///   - queue: `DispatchQueue` to be used for all upload operations
    public init(options: Options, logger: InternalLogger, queue: DispatchQueue) throws {

        self.options = options
        self.logger = logger
        self.queue = queue

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
                let semaphore = DispatchSemaphore(value: 2)

                for uploadData in cachedObjects {
                    guard let type = EmbraceUploadType(rawValue: uploadData.type) else {
                        continue
                    }
                    self.logger.debug("[EMBRACE] Waiting \(uploadData.id)")
                    semaphore.wait()
                    self.logger.debug("[EMBRACE] Entering \(uploadData.id)")
                    self.uploadData(
                        id: uploadData.id,
                        data: uploadData.data,
                        type: type,
                        waitForOperationToFinish: true,
                        completion: { completion in
                            self.logger.debug("[EMBRACE] Ending \(uploadData.id)")
                            semaphore.signal()
                        }
                    )
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
        waitForOperationToFinish: Bool = false,
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
                if !waitForOperationToFinish {
                    completion?(.success(()))
                }
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
            logger: logger) { [weak self] (cancelled, count, error) in
                if waitForOperationToFinish {
                    completion?(.success(()))
                }
                self?.queue.async { [weak self] in
                    self?.handleOperationFinished(
                        id: id,
                        type: type,
                        cancelled: cancelled,
                        attemptCount: count,
                        error: error
                    )
                    self?.clearCacheFromStaleData()
                }
            }

        // queue operations
        uploadOperation.addDependency(cacheOperation)
        operationQueue.addOperation(cacheOperation)
        operationQueue.addOperation(uploadOperation)
    }

    private func handleOperationFinished(
        id: String,
        type: EmbraceUploadType,
        cancelled: Bool,
        attemptCount: Int,
        error: Error?
    ) {
        // error?
        if cancelled == true || error != nil {
            // update attempt count in cache
            operationQueue.addOperation { [weak self] in
                do {
                    try self?.cache.updateAttemptCount(id: id, type: type, attemptCount: attemptCount)
                } catch {
                    self?.logger.debug("Error updating cache: \(error.localizedDescription)")
                }
            }
            return
        }

        // success -> clear cache
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
