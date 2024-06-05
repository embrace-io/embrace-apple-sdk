//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

public protocol EmbraceLogUploader: AnyObject {
    func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?)
}

/// Class in charge of uploading all the data colected by the Embrace SDK.
public class EmbraceUpload: EmbraceLogUploader {

    public private(set) var options: Options
    public private(set) var logger: InternalLogger
    public private(set) var queue: DispatchQueue

    let cache: EmbraceUploadCache
    let urlSession: URLSession
    let operationQueue: OperationQueue
    var reachabilityMonitor: EmbraceReachabilityMonitor?

    /// Returns an `EmbraceUpload` instance
    /// - Parameters:
    ///   - options: `EmbraceUpload.Options` instance
    ///   - logger: `EmbraceConsoleLogger` instance
    ///   - queue: `DispatchQueue` to be used for all upload operations
    public init(options: Options, logger: InternalLogger, queue: DispatchQueue) throws {

        self.options = options
        self.logger = logger
        self.queue = queue

        cache = try EmbraceUploadCache(options: options.cache)

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
            do {
                guard let cachedObjects = try self?.cache.fetchAllUploadData() else {
                    return
                }

                for uploadData in cachedObjects {
                    guard let type = EmbraceUploadType(rawValue: uploadData.type) else {
                        continue
                    }

                    self?.uploadData(
                        id: uploadData.id,
                        data: uploadData.data,
                        type: type,
                        attemptCount: uploadData.attemptCount,
                        completion: nil)
                }
            } catch {
                self?.logger.debug("Error retrying cached upload data: \(error.localizedDescription)")
            }
        }
    }

    /// Uploads the given session span data
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - data: Data of the session's payload
    ///   - completion: Completion block called when the data is succesfully cached, or when an `Error` occurs
    public func uploadSpans(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(id: id, data: data, type: .spans, completion: completion)
        }
    }

    /// Uploads the given log data
    /// - Parameters:
    ///   - id: Identifier of the log batch (has no utility aside of caching)
    ///   - data: Data of the log's payload
    ///   - completion: Completion block called when the data is succesfully cached, or when an `Error` occurs
    public func uploadLog(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(id: id, data: data, type: .log, completion: completion)
        }
    }

    // MARK: - Internal
    private func uploadData(
        id: String,
        data: Data,
        type: EmbraceUploadType,
        attemptCount: Int = 0,
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
            metadataOptions: options.metadata,
            endpoint: endpoint(for: type),
            identifier: id,
            data: data,
            retryCount: options.redundancy.automaticRetryCount,
            attemptCount: attemptCount,
            logger: logger) { [weak self] (cancelled, count, error) in

                self?.queue.async { [weak self] in
                    self?.handleOperationFinished(
                        id: id,
                        type: type,
                        cancelled: cancelled,
                        attemptCount: count,
                        error: error
                    )
                    self?.cleanCacheFromStaleData()
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
        error: Error?) {

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

    private func cleanCacheFromStaleData() {
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
