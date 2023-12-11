//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

/// Enum containing possible error codes
public enum EmbraceUploadErrorCode: Int {
    case invalidMetadata = 1000
    case invalidData = 1001
    case operationCancelled = 1002
}

/// Class in charge of uploading all the data colected by the Embrace SDK.
public class EmbraceUpload {

    public private(set) var options: Options
    public private(set) var queue: DispatchQueue

    let cache: EmbraceUploadCache
    let urlSession: URLSession
    let operationQueue: OperationQueue
    var reachabilityMonitor: EmbraceReachabilityMonitor?

    /// Returns an EmbraceUpload instance initialized on the given path.
    /// - Parameters:
    ///   - options: EmbraceUploadOptions instance
    ///   - queue: DispatchQueue to be used for all upload operations
    public init(options: Options, queue: DispatchQueue) throws {

        self.options = options
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
                ConsoleLog.debug("Error retrying cached upload data: \(error.localizedDescription)")
            }
        }
    }

    /// Uploads the given session data
    /// - Parameters:
    ///   - id: Identifier of the session
    ///   - data: Data of the session's payload
    ///   - completion: Completion block called when the data is succesfully cached, or when an `Error` occurs
    public func uploadSession(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(id: id, data: data, type: .session, completion: completion)
        }
    }

    /// Uploads the given blob data
    /// - Parameters:
    ///   - id: Identifier of the blob
    ///   - data: Data of the blob's payload
    ///   - completion: Completion block called when the data is succesfully cached, or when an `Error` occurs
    public func uploadBlob(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(id: id, data: data, type: .blob, completion: completion)
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
            completion?(.failure(internalError(code: .invalidMetadata)))
            return
        }

        // validate data
        guard data.isEmpty == false else {
            completion?(.failure(internalError(code: .invalidData)))
            return
        }

        // cache operation
        let cacheOperation = BlockOperation { [weak self] in
            do {
                try self?.cache.saveUploadData(id: id, type: type, data: data)
                completion?(.success(()))
            } catch {
                ConsoleLog.debug("Error caching upload data: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }

        // upload operation
        let uploadOperation = EmbraceUploadOperation(
            urlSession: urlSession,
            metadataOptions: options.metadata,
            endpoint: endpointForType(type),
            identifier: id,
            data: data,
            retryCount: options.redundancy.automaticRetryCount,
            attemptCount: attemptCount) { [weak self] (cancelled, count, error) in

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
                    ConsoleLog.debug("Error updating cache: \(error.localizedDescription)")
                }
            }
            return
        }

        // success -> clear cache
        operationQueue.addOperation { [weak self] in
            do {
                try self?.cache.deleteUploadData(id: id, type: type)
            } catch {
                ConsoleLog.debug("Error deleting cache: \(error.localizedDescription)")
            }
        }
    }

    private func cleanCacheFromStaleData() {
        operationQueue.addOperation { [weak self] in
            do {
                try self?.cache.clearStaleDataIfNeeded()
            } catch {
                ConsoleLog.debug("Error clearing stale date from cache: \(error.localizedDescription)")
            }
        }
    }

    private func endpointForType(_ type: EmbraceUploadType) -> URL {
        switch type {
        case .session: return options.endpoints.sessionsURL
        case .blob: return options.endpoints.blobsURL
        }
    }

    private func internalError(code: EmbraceUploadErrorCode) -> Error {
        return NSError(domain: "com.embrace", code: code.rawValue)
    }
}
