//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import os

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceUploadInternal
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceConfigInternal
    import EmbraceConfiguration
    import EmbraceObjCUtilsInternal
#endif

class LogController: LogBatcherDelegate {
    weak var storage: Storage?
    weak var upload: EmbraceLogUploader?
    weak var sessionController: SessionControllable?
    let batcher: LogBatcher
    let queue: DispatchQueue

    weak var sdkStateProvider: EmbraceSDKStateProvider?
    weak var experiments: ExperimentsHandler?
    weak var privateLogger: EmbracePrivateLogger?

    weak var stateCoordinator: StateCaptureCoordinator?

    /// This will probably be injected eventually.
    /// For consistency, I created a constant
    static let maxLogsPerBatch: Int = 20

    /// Returns the batch size to use for unsent log uploads.
    /// Defaults to adaptive sizing based on available memory.
    /// Can be overridden in tests to use a fixed value.
    var maxLogsPerBatchProvider: () -> Int = { LogController.adaptiveMaxLogsPerBatch() }

    private struct Constants {
        static let attachmentLimit: Int = 5
        static let attachmentSizeLimit: Int = 1_048_576  // 1 MiB
    }

    /// Serial queue used to chain the uploads of the logs persisted by previous processes.
    private let unsentLogsQueue: DispatchableQueue

    init(
        storage: Storage?,
        upload: EmbraceLogUploader?,
        sessionController: SessionControllable,
        batcher: LogBatcher = DefaultLogBatcher(),
        queue: DispatchQueue,
        unsentLogsQueue: DispatchableQueue = .with(label: "io.embrace.logs.unsent", qos: .utility)
    ) {
        self.storage = storage
        self.upload = upload
        self.sessionController = sessionController
        self.batcher = batcher
        self.queue = queue
        self.unsentLogsQueue = unsentLogsQueue

        self.batcher.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionEnd(notification:)),
            name: Notification.Name.embraceSessionPartWillEnd,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func onSessionEnd(notification: Notification) {
        // The notification is delivered asynchronously, so the session controller may already be on
        // another session (or none) by now. Use the ending session carried by the notification instead.
        batcher.forceEndCurrentBatch(endingSession: notification.object as? EmbraceSession)
    }

    func uploadAllPersistedLogs(_ completion: (() -> Void)? = nil) {
        guard let storage = storage else {
            completion?()
            return
        }

        let logs: [EmbraceLog] = storage.fetchAllLogs(excludingProcessIdentifier: ProcessIdentifier.current)
        if logs.isEmpty == false {
            let batchSize = maxLogsPerBatchProvider()
            send(batches: divideInBatches(logs, maxLogsPerBatch: batchSize)) {
                completion?()
            }
        } else {
            completion?()
        }
    }

    func createLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: EmbraceAttributes = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default,
        completion: ((EmbraceLog?) -> Void)? = nil
    ) {

        guard severity != .critical else {
            Embrace.logger.info("Critical logs are for internal use only!")
            return
        }

        guard let sessionController = sessionController else {
            completion?(nil)
            return
        }

        // generate attributes
        let attributesBuilder = EmbraceLogAttributesBuilder(
            storage: storage,
            sessionControllable: sessionController,
            initialAttributes: attributes
        )

        // These all need to be at the callsite in order to
        // have correct information about the users intention.
        attributesBuilder
            .addLogType(type)
            .addApplicationState()
            .addSessionIdentifier()
            .addExperiments(experiments?.encodedExperiments)
            .addCurrentStates(stateCoordinator)

        // We want to ensure the backtrace is taken on this thread,
        // but added from the queue as to not use up possibly main thread resources.
        let addStacktraceBlock: ((_ builder: EmbraceLogAttributesBuilder) -> Void)?
        switch stackTraceBehavior {
        case .default where severity == .warn || severity == .error:
            let backtrace = EmbraceBacktrace.backtrace(of: pthread_self(), threadIndex: 0)
            addStacktraceBlock = { $0.addBacktrace(backtrace) }
        case .main where severity == .warn || severity == .error:
            // A remote-thread capture comes back empty when it could not be taken (e.g. another
            // stack walk was in flight), so an empty capture attaches no stack at all.
            let backtrace = EmbraceBacktrace.backtrace(of: EmbraceGetMainThread(), threadIndex: 0)
            if backtrace.hasFrames {
                addStacktraceBlock = { $0.addBacktrace(backtrace) }
            } else {
                addStacktraceBlock = nil
                Embrace.logger.debug("stackTraceBehavior .main capture returned no frames; log sent without a stack")
            }
        case .custom(let customStackTrace) where severity == .warn || severity == .error:
            let stackTrace = customStackTrace.frames
            addStacktraceBlock = { $0.addStackTrace(stackTrace) }
        default:
            addStacktraceBlock = nil
        }

        // Now we can jump to the queue and process everything.
        queue.async { [self] in

            // Process the stack trace
            addStacktraceBlock?(attributesBuilder)

            var finalAttributes =
                attributesBuilder
                // app properties make requests to the db so can be time consuming.
                .addApplicationProperties()
                .build()

            // handle attachment data
            if let attachment {

                // embrace hosted data
                if let data = attachment.data {
                    finalAttributes[LogSemantics.keyAttachmentId] = attachment.id

                    let size = data.count
                    finalAttributes[LogSemantics.keyAttachmentSize] = String(size)

                    // check attachment count limit
                    if sessionController.attachmentCount >= Constants.attachmentLimit {
                        finalAttributes[LogSemantics.keyAttachmentErrorCode] = LogSemantics.attachmentLimitReached

                        // check attachment size limit
                    } else if size > Constants.attachmentSizeLimit {
                        finalAttributes[LogSemantics.keyAttachmentErrorCode] = LogSemantics.attachmentTooLarge
                    }

                    // upload attachment
                    else {
                        upload?.uploadAttachment(id: attachment.id, data: data, completion: nil)
                    }

                    sessionController.increaseAttachmentCount()
                }

                // pre-hosted attachment
                else if let url = attachment.url {
                    finalAttributes[LogSemantics.keyAttachmentId] = attachment.id
                    finalAttributes[LogSemantics.keyAttachmentUrl] = url.absoluteString
                }
            }

            // create log
            let log = DefaultEmbraceLog(
                id: EmbraceIdentifier.random.stringValue,
                severity: severity,
                type: type,
                timestamp: timestamp,
                body: message,
                attributes: finalAttributes,
                sessionId: sessionController.currentSession?.id
            )

            addLog(log)

            completion?(log)
        }
    }

    func addLog(_ log: EmbraceLog) {
        // save log
        storage?.saveLog(log)

        // add to batch
        batcher.addLog(log)
    }
}

extension LogController {
    func batchFinished(withLogs logs: [EmbraceLog], session: EmbraceSession?) {
        guard sdkStateProvider?.isEnabled == true,
            logs.isEmpty == false,
            let session = session ?? sessionController?.currentSession
        else {
            return
        }

        do {
            let resourcePayload = try createResourcePayload(
                userSessionId: session.userSessionId,
                processId: session.processId
            )
            let metadataPayload = try createMetadataPayload(
                userSessionId: session.userSessionId,
                processId: session.processId
            )

            // the backend drops payloads that are missing the required metadata,
            // so we discard these logs instead of uploading them
            guard resourcePayload.hasRequiredMetadata else {
                Embrace.logger.warning("Dropped \(logs.count) logs due to missing metadata!")
                storage?.remove(logs: logs)
                return
            }

            send(logs: logs, resourcePayload: resourcePayload, metadataPayload: metadataPayload, completion: {})
        } catch let exception {
            Error.couldntCreatePayload(reason: exception.localizedDescription).log()
        }
    }
}

extension LogController {
    /// A batch of persisted logs with the payloads it needs to be uploaded.
    fileprivate struct PreparedLogsBatch {
        let logs: [EmbraceLog]
        let resourcePayload: ResourcePayload
        let metadataPayload: MetadataPayload
    }

    /// Identifies the user session (or process, when the user session is unknown) a batch of logs belongs to.
    fileprivate struct PayloadKey: Hashable {
        let userSessionId: String?
        let processId: String
    }

    /// Uploads the given batches one at a time, without blocking the calling thread.
    ///
    /// The resource and metadata payloads of every batch are built synchronously before this method returns,
    /// so callers can safely clean up the stored metadata afterwards. The uploads themselves are chained
    /// asynchronously, so a missing upload completion only stalls the remaining log uploads.
    fileprivate func send(batches: [LogsBatch], completion: (() -> Void)? = nil) {
        guard sdkStateProvider?.isEnabled == true, !batches.isEmpty else {
            completion?()
            return
        }

        let preparedBatches = prepare(batches: batches)

        unsentLogsQueue.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }

            self.send(preparedBatches: preparedBatches, index: 0, completion: completion)
        }
    }

    /// Builds the payloads for each batch, reusing them for batches that belong to the same user session or process.
    ///
    /// Batches missing the required metadata are dropped, and a single private log
    /// is sent reporting the total amount of logs lost. This avoids
    /// sending one private log per batch when many of them are dropped in a row.
    fileprivate func prepare(batches: [LogsBatch]) -> [PreparedLogsBatch] {
        var payloads: [PayloadKey: (resource: ResourcePayload, metadata: MetadataPayload)] = [:]
        var preparedBatches: [PreparedLogsBatch] = []
        var droppedLogCount = 0

        for batch in batches {
            guard !batch.logs.isEmpty else {
                continue
            }

            // Since we always end batches when a session part ends
            // all the logs still in storage when the app starts should come
            // from the last user session before the app closes.
            //
            // We grab the first valid user session id from the stored logs
            // and assume all of them come from the same user session.
            //
            // If we can't find one, we use the processId instead
            let processId = batch.logs[0].processId

            // `LogSemantics.keySessionId` holds the user session id, not the session part id
            var userSessionId: EmbraceIdentifier?
            if let log = batch.logs.first(where: { $0.attributes[LogSemantics.keySessionId] != nil }) {
                if let value = log.attributes[LogSemantics.keySessionId] as? String {
                    userSessionId = EmbraceIdentifier(stringValue: value)
                }
            }

            let key = PayloadKey(userSessionId: userSessionId?.stringValue, processId: processId.stringValue)

            do {
                let payload: (resource: ResourcePayload, metadata: MetadataPayload)
                if let cached = payloads[key] {
                    payload = cached
                } else {
                    payload = (
                        resource: try createResourcePayload(userSessionId: userSessionId, processId: processId),
                        metadata: try createMetadataPayload(userSessionId: userSessionId, processId: processId)
                    )
                    payloads[key] = payload
                }

                // the backend drops payloads that are missing the required metadata,
                // so we discard these logs instead of uploading them
                guard payload.resource.hasRequiredMetadata else {
                    droppedLogCount += batch.logs.count
                    storage?.remove(logs: batch.logs)
                    continue
                }

                preparedBatches.append(
                    PreparedLogsBatch(
                        logs: batch.logs,
                        resourcePayload: payload.resource,
                        metadataPayload: payload.metadata
                    )
                )
            } catch let exception {
                Error.couldntCreatePayload(reason: exception.localizedDescription).log()
            }
        }

        if droppedLogCount > 0 {
            privateLogger?.sendPrivateLog("Logs dropped due to missing metadata: \(droppedLogCount)")
        }

        return preparedBatches
    }

    /// Uploads the batch at `index` and, once the upload module reports back, continues with the next one.
    ///
    /// Batches are processed sequentially so each compressed payload
    /// is released before the next one is allocated.
    /// Each step hops back to `unsentLogsQueue` so the payload encoding never runs on the upload module's queue,
    /// and synchronous completions don't grow the stack.
    fileprivate func send(preparedBatches: [PreparedLogsBatch], index: Int, completion: (() -> Void)?) {
        guard index < preparedBatches.count else {
            completion?()
            return
        }

        autoreleasepool {
            let batch = preparedBatches[index]
            send(
                logs: batch.logs,
                resourcePayload: batch.resourcePayload,
                metadataPayload: batch.metadataPayload,
                completion: { [weak self] in
                    guard let self = self else {
                        completion?()
                        return
                    }

                    self.unsentLogsQueue.async {
                        self.send(preparedBatches: preparedBatches, index: index + 1, completion: completion)
                    }
                }
            )
        }
    }

    fileprivate func send(
        logs: [EmbraceLog],
        resourcePayload: ResourcePayload,
        metadataPayload: MetadataPayload,
        completion: (() -> Void)?
    ) {
        guard let upload = upload else {
            completion?()
            return
        }

        let logPayloads = logs.map { LogPayloadBuilder.build(log: $0) }
        let envelope = PayloadEnvelope.init(
            data: logPayloads,
            resource: resourcePayload,
            metadata: metadataPayload
        )

        do {
            let envelopeData = try JSONEncoder().encode(envelope).gzipped()
            let payloadTypes = logsPayloadTypes(logs)

            upload.uploadLog(id: UUID().uuidString, data: envelopeData, payloadTypes: payloadTypes) { [weak self] result in
                defer { completion?() }
                guard let self = self else {
                    return
                }
                if case Result.failure(let error) = result {
                    Error.couldntUpload(reason: error.localizedDescription).log()
                    return
                }

                self.storage?.remove(logs: logs)
            }
        } catch let exception {
            Error.couldntCreatePayload(reason: exception.localizedDescription).log()
            completion?()
        }
    }

    static func adaptiveMaxLogsPerBatch() -> Int {
        #if os(macOS)
            return maxLogsPerBatch
        #else
            let availableMemory = os_proc_available_memory()

            switch availableMemory {
            case 0..<(15 * 1024 * 1024):
                return 1
            case ..<(30 * 1024 * 1024):
                return 5
            case ..<(50 * 1024 * 1024):
                return 10
            default:
                return maxLogsPerBatch
            }
        #endif
    }

    fileprivate func divideInBatches(_ logs: [EmbraceLog], maxLogsPerBatch: Int = LogController.maxLogsPerBatch) -> [LogsBatch] {
        var batches: [LogsBatch] = []
        var batch: LogsBatch = .init(limits: .init(maxBatchAge: .infinity, maxLogsPerBatch: maxLogsPerBatch))
        for log in logs {
            let result = batch.add(log: log)
            switch result {
            case .success(let batchState):
                if batchState == .closed {
                    batches.append(batch)
                    batch = LogsBatch(limits: .init(maxLogsPerBatch: maxLogsPerBatch))
                }
            case .failure:
                // This shouldn't happen.
                // However, we add this logic to ensure everything works fine
                batches.append(batch)
                batch = LogsBatch(limits: .init(), logs: [log])
            }
        }

        if batch.batchState != .closed && !batch.logs.isEmpty {
            batches.append(batch)
        }

        return batches
    }

    fileprivate func createResourcePayload(
        userSessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier = ProcessIdentifier.current
    ) throws -> ResourcePayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }

        var resources: [EmbraceMetadata] = []

        if let userSessionId = userSessionId {
            resources = storage.fetchResources(userSessionId: userSessionId, processId: processId)
        } else {
            resources = storage.fetchResourcesForProcessId(processId)
        }

        return ResourcePayload(from: resources)
    }

    fileprivate func createMetadataPayload(
        userSessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier = ProcessIdentifier.current
    ) throws -> MetadataPayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }

        var metadata: [EmbraceMetadata] = []

        if let userSessionId = userSessionId {
            let properties = storage.fetchCustomProperties(userSessionId: userSessionId, processId: processId)
            let tags = storage.fetchPersonaTags(userSessionId: userSessionId, processId: processId)
            metadata.append(contentsOf: properties)
            metadata.append(contentsOf: tags)
        } else {
            metadata = storage.fetchPersonaTagsForProcessId(processId)
        }

        return MetadataPayload(from: metadata)
    }

    /// Returns the comma separated list of all the `emb.types` for an array of `EmbraceLogs`
    fileprivate func logsPayloadTypes(_ logs: [EmbraceLog]) -> String {
        guard logs.count > 0 else {
            return ""
        }

        let types = logs.compactMap { $0.attributes[LogSemantics.keyEmbraceType] as? String }
        let set = Set(types)
        return set.joined(separator: ",")
    }
}

extension LogController {
    enum Error: LocalizedError, CustomNSError {
        case couldntAccessStorageModule
        case couldntAccessUploadModule
        case couldntUpload(reason: String)
        case couldntCreatePayload(reason: String)
        case couldntAccessBatches(reason: String)

        static var errorDomain: String {
            return "Embrace"
        }

        var errorCode: Int {
            switch self {
            case .couldntAccessStorageModule:
                -1
            case .couldntAccessUploadModule:
                -2
            case .couldntCreatePayload:
                -3
            case .couldntUpload:
                -4
            case .couldntAccessBatches:
                -5
            }
        }

        var errorDescription: String? {
            switch self {
            case .couldntAccessStorageModule:
                "Couldn't access to the storage layer"
            case .couldntAccessUploadModule:
                "Couldn't access to the upload module"
            case .couldntUpload(let reason):
                "Couldn't upload logs: \(reason)"
            case .couldntCreatePayload(let reason):
                "Couldn't create payload: \(reason)"
            case .couldntAccessBatches(let reason):
                "There was a problem fetching batches: \(reason)"
            }
        }

        var localizedDescription: String {
            return self.errorDescription ?? "No Matching Error"
        }

        func log() {
            Embrace.logger.error(localizedDescription)
        }
    }
}
