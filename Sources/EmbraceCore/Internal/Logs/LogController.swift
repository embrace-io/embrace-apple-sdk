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
    import EmbraceOTelInternal
    import EmbraceConfiguration
#endif

protocol LogControllable: LogBatcherDelegate {
    func uploadAllPersistedLogs()
    func createLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: EmbraceLogAttachment?,
        attributes: [String: String],
        stackTraceBehavior: EmbraceStackTraceBehavior,
        send: Bool,
        completion: ((EmbraceLog?) -> Void)?
    )
}

class LogController: LogControllable {
    private(set) weak var sessionController: SessionControllable?
    private weak var storage: Storage?
    private weak var upload: EmbraceLogUploader?
    private let queue: DispatchQueue

    weak var sdkStateProvider: EmbraceSDKStateProvider?

    var otel: EmbraceOTelBridge = EmbraceOTel()  // var so we can inject a mock for testing

    /// This will probably be injected eventually.
    /// For consistency, I created a constant
    static let maxLogsPerBatch: Int = 20

    struct MutableState {
        var limits: LogsLimits = LogsLimits()
    }
    private let state = EmbraceMutex(MutableState())

    var limits: LogsLimits {
        get { state.withLock { $0.limits } }
        set { state.withLock { $0.limits = newValue } }
    }

    var currentSessionId: EmbraceIdentifier? {
        sessionController?.currentSession?.id
    }

    static let attachmentLimit: Int = 5
    static let attachmentSizeLimit: Int = 1_048_576  // 1 MiB

    init(
        storage: Storage?,
        upload: EmbraceLogUploader?,
        controller: SessionControllable,
        queue: DispatchQueue
    ) {
        self.storage = storage
        self.upload = upload
        self.sessionController = controller
        self.queue = queue
    }

    func uploadAllPersistedLogs() {
        guard let storage = storage else {
            return
        }

        let logs: [EmbraceLog] = storage.fetchAll(excludingProcessIdentifier: ProcessIdentifier.current)
        if logs.count > 0 {
            send(batches: divideInBatches(logs))
        }
    }

    public func createLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType = .message,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .defaultStackTrace(),
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

        // things that require the state from this thread
        attributesBuilder
            .addLogType(type)
            .addApplicationState()
            .addSessionIdentifier()

        // We want to ensure the backtrace is taken this thread,
        // but added from the queue as to not use up possibly main thread resources.
        var addStacktraceBlock: ((_ builder: EmbraceLogAttributesBuilder) -> Void)?
        if severity == .warn || severity == .error,
            let frames = stackTraceBehavior.stackTraceFames {
            addStacktraceBlock = { $0.addStackTrace(frames) }
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
                    if sessionController.attachmentCount >= Self.attachmentLimit {
                        finalAttributes[LogSemantics.keyAttachmentErrorCode] = LogSemantics.attachmentLimitReached

                        // check attachment size limit
                    } else if size > Self.attachmentSizeLimit {
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
                timestamp: timestamp,
                body: message,
                attributes: finalAttributes,
                sessionId: sessionController.currentSession?.id
            )

            if send {
                // TODO: add to batch

                // save log
                storage?.saveLog(log)
            }

            completion?(log)
        }
    }
}

extension LogController {
    func batchFinished(withLogs logs: [EmbraceLog]) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        do {
            guard let sessionId = sessionController?.currentSession?.id, logs.isEmpty == false else {
                return
            }
            let resourcePayload = try createResourcePayload(sessionId: sessionId)
            let metadataPayload = try createMetadataPayload(sessionId: sessionId)
            send(logs: logs, resourcePayload: resourcePayload, metadataPayload: metadataPayload)
        } catch let exception {
            Error.couldntCreatePayload(reason: exception.localizedDescription).log()
        }
    }
}

extension LogController {
    fileprivate func send(batches: [LogsBatch]) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        guard batches.isEmpty == false else {
            return
        }

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

                send(
                    logs: batch.logs,
                    resourcePayload: resourcePayload,
                    metadataPayload: metadataPayload
                )
            } catch let exception {
                Error.couldntCreatePayload(reason: exception.localizedDescription).log()
            }
        }
    }

    fileprivate func send(
        logs: [EmbraceLog],
        resourcePayload: ResourcePayload,
        metadataPayload: MetadataPayload
    ) {
        guard let upload = upload else {
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
        }
    }

    fileprivate func divideInBatches(_ logs: [EmbraceLog]) -> [LogsBatch] {
        var batches: [LogsBatch] = []
        var batch: LogsBatch = .init(limits: .init(maxBatchAge: .infinity, maxLogsPerBatch: Self.maxLogsPerBatch))
        for log in logs {
            let result = batch.add(log: log)
            switch result {
            case .success(let batchState):
                if batchState == .closed {
                    batches.append(batch)
                    batch = LogsBatch(limits: .init(maxLogsPerBatch: Self.maxLogsPerBatch))
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
