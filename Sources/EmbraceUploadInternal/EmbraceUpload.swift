//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

public protocol EmbraceLogUploader: AnyObject {
    func uploadLog(id: String, data: Data, payloadTypes: String, completion: ((Result<(), Error>) -> Void)?)
    func uploadAttachment(id: String, data: Data, completion: ((Result<(), Error>) -> Void)?)
}

/// Class in charge of uploading all the data collected by the Embrace SDK.
public class EmbraceUpload: EmbraceLogUploader {

    public private(set) var options: Options
    public private(set) var logger: InternalLogger

    /// Coordination queue — serializes all state management: cache reads/writes,
    /// in-flight tracking, last-operation references, and queue-fill decisions.
    /// Never executes network requests. Never blocks on the operation queues.
    public let queue: DispatchQueue

    /// Upload queues — only contain upload operations (network work).
    let spansQueue: OperationQueue
    let _spansQueue: DispatchQueue
    let logsQueue: OperationQueue
    let _logsQueue: DispatchQueue
    let attachmentsQueue: OperationQueue
    let _attachmentsQueue: DispatchQueue

    /// Per-type set of record IDs that currently have active upload operations.
    /// Read and written exclusively on the coordination queue.
    private var inFlightIDs: [EmbraceUploadType: Set<String>] = [
        .spans: [], .log: [], .attachment: []
    ]

    /// Weak references to the most recently enqueued upload operation for ordered types.
    /// Used to chain new operations against their predecessor.
    private weak var lastSpansOperation: Operation?
    private weak var lastLogsOperation: Operation?

    private let urlSession: URLSession
    let cache: EmbraceUploadCache
    private var reachabilityMonitor: EmbraceReachabilityMonitor?

    /// Returns an `EmbraceUpload` instance
    /// - Parameters:
    ///   - options: `EmbraceUpload.Options` instance
    ///   - logger: `InternalLogger` instance
    ///   - queue: `DispatchQueue` to be used as the coordination queue
    public init(
        options: Options,
        logger: InternalLogger,
        queue: DispatchQueue
    ) throws {

        self.options = options
        self.logger = logger
        self.queue = queue

        cache = try EmbraceUploadCache(options: options.cache, logger: logger)

        urlSession = URLSession(configuration: options.urlSessionConfiguration)

        // Serial queues for ordered types
        spansQueue = OperationQueue()
        spansQueue.maxConcurrentOperationCount = 1
        _spansQueue = DispatchQueue(label: "com.embrace.upload.spans", qos: .utility)
        spansQueue.underlyingQueue = _spansQueue

        logsQueue = OperationQueue()
        logsQueue.maxConcurrentOperationCount = 1
        _logsQueue = DispatchQueue(label: "com.embrace.upload.logs", qos: .utility)
        logsQueue.underlyingQueue = _logsQueue

        // Concurrent queue for attachments (no ordering constraint)
        attachmentsQueue = OperationQueue()
        _attachmentsQueue = DispatchQueue(label: "com.embrace.upload.attachments", qos: .utility)
        attachmentsQueue.underlyingQueue = _attachmentsQueue

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

    // MARK: - Public API

    /// Attempts to upload all the available cached data.
    /// Called at process launch and on internet reconnection.
    public func retryCachedData(_ completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }

            // Clear stale data
            self.cache.clearStaleDataIfNeeded()

            // Fill queues — records are fetched in date order.
            // inFlightIDs is NOT reset here. On internet reconnection, queues may still
            // have active operations whose IDs are correctly tracked.
            // At process launch, the sets are already empty (freshly initialized).
            self.fillQueue(for: .spans)
            self.fillQueue(for: .log)
            self.fillQueue(for: .attachment)

            completion?()
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
    ///   - payloadTypes: Comma separated list of all the emb.types of logs that are being uploaded
    ///   - completion: Completion block called when the data is successfully cached, or when an `Error` occurs
    public func uploadLog(id: String, data: Data, payloadTypes: String = "", completion: ((Result<(), Error>) -> Void)?) {
        queue.async { [weak self] in
            self?.uploadData(
                id: id,
                data: data,
                type: .log,
                payloadTypes: payloadTypes,
                completion: completion
            )
        }
    }

    /// Uploads the given attachment data
    /// - Parameters:
    ///   - id: Identifier of the attachment
    ///   - data: The attachment's data
    ///   - completion: Completion block called when the data is successfully cached, or when an `Error` occurs
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

    // MARK: - Internal: Upload Data (Cache-First)

    /// Validates input, saves to cache synchronously, signals durability via completion,
    /// then calls fillQueue to create upload operations if the queue has capacity.
    private func uploadData(
        id: String,
        data: Data,
        type: EmbraceUploadType,
        payloadTypes: String? = nil,
        completion: ((Result<(), Error>) -> Void)?
    ) {

        // validate identifier
        guard !id.isEmpty else {
            completion?(.failure(EmbraceUploadError.internalError(.invalidMetadata)))
            return
        }

        // validate data
        guard !data.isEmpty else {
            completion?(.failure(EmbraceUploadError.internalError(.invalidData)))
            return
        }

        // Save to cache synchronously (we are on the coordination queue).
        // Data is durable after this call.
        if !cache.saveUploadData(id: id, type: type, data: data, payloadTypes: payloadTypes) {
            logger.debug("Error caching upload data!")
        }

        // Signal durability to the caller
        completion?(.success(()))

        // Try to fill the queue (may create an operation for this record or leave it in cache)
        fillQueue(for: type)
    }

    // MARK: - Internal: Queue Fill Mechanism

    /// The single mechanism for creating upload operations. Called after every cache write
    /// and after every operation completion.
    ///
    /// Must be called on the coordination queue.
    private func fillQueue(for type: EmbraceUploadType) {
        let queue = uploadQueue(for: type)
        let currentCount = inFlightIDs[type]?.count ?? 0
        let limit = options.redundancy.queueLimit

        guard currentCount < limit else { return }

        let availableSlots = limit - currentCount
        let excludedIDs = inFlightIDs[type] ?? []

        let records = cache.fetchUploadData(
            type: type,
            excludingIDs: excludedIDs,
            limit: availableSlots
        )

        for record in records {
            let operation = createUploadOperation(
                id: record.id,
                type: type,
                data: record.data,
                payloadTypes: record.payloadTypes
            )

            // Chain for ordered types
            if type == .spans {
                if let last = lastSpansOperation, !last.isFinished {
                    operation.addDependency(last)
                }
                lastSpansOperation = operation
            } else if type == .log {
                if let last = lastLogsOperation, !last.isFinished {
                    operation.addDependency(last)
                }
                lastLogsOperation = operation
            }

            inFlightIDs[type]?.insert(record.id)
            queue.addOperation(operation)
        }
    }

    // MARK: - Internal: Operation Factory

    private func createUploadOperation(
        id: String,
        type: EmbraceUploadType,
        data: Data,
        payloadTypes: String?
    ) -> EmbraceUploadOperation {

        let operationCompletion: EmbraceUploadOperationCompletion = { [weak self] result, _ in
            self?.queue.async { [weak self] in
                self?.handleOperationFinished(id: id, type: type, result: result)
            }
        }

        let operationQueue = uploadQueue(for: type)

        if type == .attachment {
            return EmbraceAttachmentUploadOperation(
                urlSession: urlSession,
                queue: operationQueue.underlyingQueue ?? .global(qos: .utility),
                metadataOptions: options.metadata,
                endpoint: endpoint(for: type),
                identifier: id,
                data: data,
                payloadTypes: payloadTypes,
                retryCount: options.redundancy.automaticRetryCount,
                exponentialBackoffBehavior: options.redundancy.exponentialBackoffBehavior,
                attemptCount: 0,
                logger: logger,
                completion: operationCompletion
            )
        }

        return EmbraceUploadOperation(
            urlSession: urlSession,
            queue: operationQueue.underlyingQueue ?? .global(qos: .utility),
            metadataOptions: options.metadata,
            endpoint: endpoint(for: type),
            identifier: id,
            data: data,
            payloadTypes: payloadTypes,
            retryCount: options.redundancy.automaticRetryCount,
            exponentialBackoffBehavior: options.redundancy.exponentialBackoffBehavior,
            attemptCount: 0,
            logger: logger,
            completion: operationCompletion
        )
    }

    // MARK: - Internal: Operation Completion

    private func handleOperationFinished(
        id: String,
        type: EmbraceUploadType,
        result: EmbraceUploadOperationResult
    ) {
        // Remove from in-flight tracking
        inFlightIDs[type]?.remove(id)

        // Delete from cache unless cancelled (cancelled records are replayed on next launch)
        switch result {
        case .success, .failure:
            cache.deleteUploadData(id: id, type: type)
        case .cancelled:
            break
        }

        // Refill the queue
        fillQueue(for: type)
    }

    // MARK: - Internal: Helpers

    private func uploadQueue(for type: EmbraceUploadType) -> OperationQueue {
        switch type {
        case .spans: return spansQueue
        case .log: return logsQueue
        case .attachment: return attachmentsQueue
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

extension EmbraceUpload {
    public func retryCachedData() async {
        await withCheckedContinuation { continuation in
            retryCachedData {
                continuation.resume()
            }
        }
    }
}
