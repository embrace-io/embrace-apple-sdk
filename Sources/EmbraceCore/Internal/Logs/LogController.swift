//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

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

    var currentSessionId: EmbraceIdentifier? {
        sessionController?.currentSession?.id
    }

    struct Constants {
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
            send(batches: divideInBatches(logs)) {
                completion?()
            }
        } else {
            completion?()
        }
    }

    public func createLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default,
        send: Bool = true,
        completion: ((EmbraceLog?) -> Void)? = nil
    ) {
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
            if EmbraceBacktrace.isAvailable {
                let backtrace = EmbraceBacktrace.backtrace(of: pthread_self(), suspendingThreads: false)
                addStacktraceBlock = { $0.addBacktrace(backtrace) }
            } else {
                let stacktrace = Thread.callStackSymbols
                addStacktraceBlock = { $0.addStackTrace(stacktrace) }
            }
        case .main where severity == .warn || severity == .error:
            if EmbraceBacktrace.isAvailable {
                let backtrace = EmbraceBacktrace.backtrace(of: EmbraceGetMainThread(), suspendingThreads: true)
                addStacktraceBlock = { $0.addBacktrace(backtrace) }
            } else {
                addStacktraceBlock = nil
                Embrace.logger.warning("stackTraceBehavior .main is unavailable without EmbraceBacktrace")
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

            if send {
                addLog(log)
            }

            completion?(log)
        }
    }

    public func addLog(_ log: EmbraceLog) {
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
        guard sdkStateProvider?.isEnabled == true else {
            completion?()
            return
        }

        guard batches.isEmpty == false else {
            completion?()
            return
        }

        let group = DispatchGroup()
        group.enter()

        for batch in batches {
            do {
                guard batch.logs.isEmpty == false else {
                    continue
                }

                // Since we always end batches when a session ends
                // all the logs still in storage when the app starts should come
                // from the last session before the app closes.
                //
                // We grab the first valid sessionId from the stored logs
                // and assume all of them come from the same session.
                //
                // If we can't find a sessionId, we use the processId instead

                var sessionId: EmbraceIdentifier?
                if let log = batch.logs.first(where: { $0.attributes[LogSemantics.keySessionId] != nil }) {
                    if let value = log.attributes[LogSemantics.keySessionId] {
                        sessionId = EmbraceIdentifier(stringValue: value)
                    }
                }

                let processId = batch.logs[0].processId
                let resourcePayload = try createResourcePayload(sessionId: sessionId, processId: processId)
                let metadataPayload = try createMetadataPayload(sessionId: sessionId, processId: processId)

                group.enter()

                send(
                    logs: batch.logs,
                    resourcePayload: resourcePayload,
                    metadataPayload: metadataPayload,
                    completion: {
                        group.leave()
                    }
                )
            } catch let exception {
                Error.couldntCreatePayload(reason: exception.localizedDescription).log()
            }
        }

        group.leave()
        group.notify(queue: .global(qos: .default)) {
            completion?()
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
            metadata: metadataPayload)
        do {
            let envelopeData = try JSONEncoder().encode(envelope).gzipped()
            upload.uploadLog(id: UUID().uuidString, data: envelopeData) { [weak self] result in
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

    fileprivate func divideInBatches(_ logs: [EmbraceLog]) -> [LogsBatch] {
        var batches: [LogsBatch] = []
        var batch: LogsBatch = .init(limits: batcher.logBatchLimits)

        for log in logs {
            let result = batch.add(log: log)
            switch result {
            case .success(let batchState):
                if batchState == .closed {
                    batches.append(batch)
                    batch = LogsBatch(limits: batcher.logBatchLimits)
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
}

extension LogController {
    enum Error: LocalizedError, CustomNSError {
        case couldntAccessStorageModule
        case couldntAccessUploadModule
        case couldntUpload(reason: String)
        case couldntCreatePayload(reason: String)
        case couldntAccessBatches(reason: String)

        public static var errorDomain: String {
            return "Embrace"
        }

        public var errorCode: Int {
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

        public var errorDescription: String? {
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

        public var localizedDescription: String {
            return self.errorDescription ?? "No Matching Error"
        }

        func log() {
            Embrace.logger.error(localizedDescription)
        }
    }
}
