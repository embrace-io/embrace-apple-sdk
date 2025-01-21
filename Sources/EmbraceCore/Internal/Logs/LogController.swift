//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceConfigInternal
import EmbraceOTelInternal

protocol LogControllable: LogBatcherDelegate {
    func uploadAllPersistedLogs()
    func createLog(
        _ message: String,
        severity: LogSeverity,
        type: LogType,
        timestamp: Date,
        attachment: Data?,
        attachmentId: String?,
        attachmentUrl: URL?,
        attachmentSize: Int?,
        attributes: [String: String],
        stackTraceBehavior: StackTraceBehavior
    )
}

class LogController: LogControllable {
    private(set) weak var sessionController: SessionControllable?
    private weak var storage: Storage?
    private weak var upload: EmbraceLogUploader?

    weak var sdkStateProvider: EmbraceSDKStateProvider?

    var otel: EmbraceOTelBridge = EmbraceOTel() // var so we can inject a mock for testing

    /// This will probably be injected eventually.
    /// For consistency, I created a constant
    static let maxLogsPerBatch: Int = 20

    static let attachmentLimit: Int = 5
    static let attachmentSizeLimit: Int = 1048576 // 1 MiB

    init(storage: Storage?,
         upload: EmbraceLogUploader?,
         controller: SessionControllable) {
        self.storage = storage
        self.upload = upload
        self.sessionController = controller
    }

    func uploadAllPersistedLogs() {
        guard let storage = storage else {
            return
        }
        do {
            let logs: [LogRecord] = try storage.fetchAll(excludingProcessIdentifier: .current)
            if logs.count > 0 {
                send(batches: divideInBatches(logs))
            }
        } catch let exception {
            Error.couldntAccessBatches(reason: exception.localizedDescription).log()
            try? storage.removeAllLogs()
        }
    }

    public func createLog(
        _ message: String,
        severity: LogSeverity,
        type: LogType = .message,
        timestamp: Date = Date(),
        attachment: Data? = nil,
        attachmentId: String? = nil,
        attachmentUrl: URL? = nil,
        attachmentSize: Int? = nil,
        attributes: [String: String] = [:],
        stackTraceBehavior: StackTraceBehavior = .default
    ) {
        guard let sessionController = sessionController else {
            return
        }

        // generate attributes
        let attributesBuilder = EmbraceLogAttributesBuilder(
            storage: storage,
            sessionControllable: sessionController,
            initialAttributes: attributes
        )

        /*
         If we want to keep this method cleaner, we could move this log to `EmbraceLogAttributesBuilder`
         However that would cause to always add a frame to the stacktrace.
         */
        if stackTraceBehavior == .default && (severity == .warn || severity == .error) {
            let stackTrace: [String] = Thread.callStackSymbols
            attributesBuilder.addStackTrace(stackTrace)
        }

        var finalAttributes = attributesBuilder
            .addLogType(type)
            .addApplicationState()
            .addApplicationProperties()
            .addSessionIdentifier()
            .build()

        // handle attachment data
        if let attachment = attachment {

            sessionController.increaseAttachmentCount()

            let id = UUID().withoutHyphen
            finalAttributes[LogSemantics.keyAttachmentId] = id

            let size = attachment.count
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
                upload?.uploadAttachment(id: id, data: attachment, completion: nil)
            }
        }

        // handle pre-uploaded attachment
        else if let attachmentId = attachmentId,
                let attachmentUrl = attachmentUrl {

            finalAttributes[LogSemantics.keyAttachmentId] = attachmentId
            finalAttributes[LogSemantics.keyAttachmentUrl] = attachmentUrl.absoluteString

            if let attachmentSize = attachmentSize {
                finalAttributes[LogSemantics.keyAttachmentSize] = String(attachmentSize)
            }
        }

        otel.log(message, severity: severity, timestamp: timestamp, attributes: finalAttributes)
    }
}

extension LogController {
    func batchFinished(withLogs logs: [LogRecord]) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        do {
            guard let sessionId = sessionController?.currentSession?.id, logs.count > 0 else {
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

private extension LogController {
    func send(batches: [LogsBatch]) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        guard batches.count > 0 else {
            return
        }

        for batch in batches {
            do {
                guard batch.logs.count > 0 else {
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

                var sessionId: SessionIdentifier?
                if let log = batch.logs.first(where: { $0.attributes[LogSemantics.keySessionId] != nil }) {
                    sessionId = SessionIdentifier(string: log.attributes[LogSemantics.keySessionId]?.description)
                }

                let processId = batch.logs[0].processIdentifier

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

    func send(
        logs: [LogRecord],
        resourcePayload: ResourcePayload,
        metadataPayload: MetadataPayload
    ) {
        guard let upload = upload else {
            return
        }
        let logPayloads = logs.map { LogPayloadBuilder.build(log: $0) }
        let envelope = PayloadEnvelope.init(data: logPayloads,
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

                try? self.storage?.remove(logs: logs)
            }
        } catch let exception {
            Error.couldntCreatePayload(reason: exception.localizedDescription).log()
        }
    }

    func divideInBatches(_ logs: [LogRecord]) -> [LogsBatch] {
        var batches: [LogsBatch] = []
        var batch: LogsBatch = .init(limits: .init(maxBatchAge: .infinity, maxLogsPerBatch: Self.maxLogsPerBatch))
        for log in logs {
            let result = batch.add(logRecord: log)
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

    func createResourcePayload(sessionId: SessionIdentifier?,
                               processId: ProcessIdentifier = ProcessIdentifier.current
    ) throws -> ResourcePayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }

        var resources: [MetadataRecord] = []

        if let sessionId = sessionId {
            resources = try storage.fetchResourcesForSessionId(sessionId)
        } else {
            resources = try storage.fetchResourcesForProcessId(processId)
        }

        return ResourcePayload(from: resources)
    }

    func createMetadataPayload(sessionId: SessionIdentifier?,
                               processId: ProcessIdentifier = ProcessIdentifier.current
    ) throws -> MetadataPayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }

        var metadata: [MetadataRecord] = []

        if let sessionId = sessionId {
            let properties = try storage.fetchCustomPropertiesForSessionId(sessionId)
            let tags = try storage.fetchPersonaTagsForSessionId(sessionId)
            metadata.append(contentsOf: properties)
            metadata.append(contentsOf: tags)
        } else {
            metadata = try storage.fetchPersonaTagsForProcessId(processId)
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
