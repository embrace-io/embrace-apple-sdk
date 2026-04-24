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

    /// This will probably be injected eventually.
    /// For consistency, I created a constant
    static let maxLogsPerBatch: Int = 20

    /// Returns the batch size to use for unsent log uploads.
    /// Defaults to adaptive sizing based on available memory.
    /// Can be overridden in tests to use a fixed value.
    var maxLogsPerBatchProvider: () -> Int = { LogController.adaptiveMaxLogsPerBatch() }

    var currentSessionId: EmbraceIdentifier? {
        sessionController?.currentSession?.id
    }

    private struct Constants {
        static let attachmentLimit: Int = 5
        static let attachmentSizeLimit: Int = 1_048_576  // 1 MiB
    }

    init(
        storage: Storage?,
        upload: EmbraceLogUploader?,
        sessionController: SessionControllable,
        batcher: LogBatcher = DefaultLogBatcher(),
        queue: DispatchQueue
    ) {
        self.storage = storage
        self.upload = upload
        self.sessionController = sessionController
        self.batcher = batcher
        self.queue = queue

        self.batcher.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionEnd),
            name: Notification.Name.embraceSessionWillEnd,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func onSessionEnd() {
        batcher.forceEndCurrentBatch(waitUntilFinished: true)
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
        send: Bool = true,
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

        // We want to ensure the backtrace is taken on this thread,
        // but added from the queue as to not use up possibly main thread resources.
        let addStacktraceBlock: ((_ builder: EmbraceLogAttributesBuilder) -> Void)?
        switch stackTraceBehavior {
        case .default where severity == .warn || severity == .error:
            let backtrace = EmbraceBacktrace.backtrace(of: pthread_self(), threadIndex: 0)
            addStacktraceBlock = { $0.addBacktrace(backtrace) }
        case .main where severity == .warn || severity == .error:
            let backtrace = EmbraceBacktrace.backtrace(of: EmbraceGetMainThread(), threadIndex: 0)
            addStacktraceBlock = { $0.addBacktrace(backtrace) }
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

            if send {
                addLog(log)
            }

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
    func batchFinished(withLogs logs: [EmbraceLog]) {
        guard sdkStateProvider?.isEnabled == true,
            logs.isEmpty == false,
            let sessionId = sessionController?.currentSession?.id
        else {
            return
        }

        do {
            let resourcePayload = try createResourcePayload(sessionId: sessionId)
            let metadataPayload = try createMetadataPayload(sessionId: sessionId)
            send(logs: logs, resourcePayload: resourcePayload, metadataPayload: metadataPayload, completion: {})
        } catch let exception {
            Error.couldntCreatePayload(reason: exception.localizedDescription).log()
        }
    }
}

extension LogController {
    fileprivate func send(batches: [LogsBatch], completion: (() -> Void)? = nil) {
        guard sdkStateProvider?.isEnabled == true, !batches.isEmpty else {
            completion?()
            return
        }

        // Process batches sequentially so each compressed payload
        // is released before the next one is allocated.
        let semaphore = DispatchSemaphore(value: 0)

        for batch in batches {
            autoreleasepool {
                guard !batch.logs.isEmpty else {
                    return
                }

                // Since we always end batches when a session ends
                // all the logs still in storage when the app starts should come
                // from the last session before the app closes.
                //
                // We grab the first valid sessionId from the stored logs
                // and assume all of them come from the same session.
                //
                // If we can't find a sessionId, we use the processId instead
                let processId = batch.logs[0].processId

                do {
                    var sessionId: EmbraceIdentifier?
                    if let log = batch.logs.first(where: { $0.attributes[LogSemantics.keySessionId] != nil }) {
                        if let value = log.attributes[LogSemantics.keySessionId] as? String {
                            sessionId = EmbraceIdentifier(stringValue: value)
                        }
                    }

                    let resourcePayload = try createResourcePayload(sessionId: sessionId, processId: processId)
                    let metadataPayload = try createMetadataPayload(sessionId: sessionId, processId: processId)

                    send(
                        logs: batch.logs,
                        resourcePayload: resourcePayload,
                        metadataPayload: metadataPayload,
                        completion: { semaphore.signal() }
                    )

                    semaphore.wait()

                } catch let exception {
                    Error.couldntCreatePayload(reason: exception.localizedDescription).log()
                }
            }
        }

        completion?()
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
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier = ProcessIdentifier.current
    ) throws -> ResourcePayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }

        var resources: [EmbraceMetadata] = []

        if let sessionId = sessionId {
            resources = storage.fetchResourcesForSessionId(sessionId)
        } else {
            resources = storage.fetchResourcesForProcessId(processId)
        }

        return ResourcePayload(from: resources)
    }

    fileprivate func createMetadataPayload(
        sessionId: EmbraceIdentifier?,
        processId: EmbraceIdentifier = ProcessIdentifier.current
    ) throws -> MetadataPayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }

        var metadata: [EmbraceMetadata] = []

        if let sessionId = sessionId {
            let properties = storage.fetchCustomPropertiesForSessionId(sessionId)
            let tags = storage.fetchPersonaTagsForSessionId(sessionId)
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
