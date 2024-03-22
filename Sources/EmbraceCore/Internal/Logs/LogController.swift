//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceUpload
import EmbraceCommon

protocol LogControllable: LogBatcherDelegate {
    func uploadAllPersistedLogs()
}

class LogController: LogControllable {
    private(set) weak var sessionController: SessionControllable?
    private weak var storage: Storage?
    private weak var upload: EmbraceLogUploader?
    /// This will probably be injected eventually.
    /// For consistency, I created a constant
    static let maxLogsPerBatch: Int = 20

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
}

extension LogController {
    func batchFinished(withLogs logs: [LogRecord]) {
        do {
            guard let sessionId = sessionController?.currentSession?.id else {
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
        guard batches.count > 0 else {
            return
        }
        guard let sessionId = sessionController?.currentSession?.id else {
            return
        }

        do {
            let resourcePayload = try createResourcePayload(sessionId: sessionId)
            let metadataPayload = try createMetadataPayload(sessionId: sessionId)

            batches.forEach { batch in
                send(
                    logs: batch.logs,
                    resourcePayload: resourcePayload,
                    metadataPayload: metadataPayload
                )
            }
        } catch let exception {
            Error.couldntCreatePayload(reason: exception.localizedDescription).log()
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

    func createResourcePayload(sessionId: SessionIdentifier) throws -> ResourcePayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }
        let resources = try storage.fetchResourcesForSessionId(sessionId)
        return ResourcePayload(from: resources)
    }

    func createMetadataPayload(sessionId: SessionIdentifier) throws -> MetadataPayload {
        guard let storage = storage else {
            throw Error.couldntAccessStorageModule
        }
        let metadata = try storage.fetchCustomPropertiesForSessionId(sessionId)
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
            ConsoleLog.error(localizedDescription)
        }
    }
}
