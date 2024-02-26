//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel
import EmbraceStorage

class DefaultEmbraceLogSharedState: EmbraceLogSharedState {
    let processors: [EmbraceLogRecordProcessor]
    let resourceProvider: EmbraceResourceProvider
    private(set) var config: any EmbraceLoggerConfig

    init(
        config: any EmbraceLoggerConfig,
        processors: [EmbraceLogRecordProcessor],
        resourceProvider: EmbraceResourceProvider
    ) {
        self.config = config
        self.processors = processors
        self.resourceProvider = resourceProvider
    }

    func update(_ config: any EmbraceLoggerConfig) {
        self.config = config
    }
}

extension DefaultEmbraceLogSharedState {
    static func create(
        storage: EmbraceStorage,
        exporter: EmbraceLogRecordExporter? = nil
    ) -> DefaultEmbraceLogSharedState {
        var exporters: [EmbraceLogRecordExporter] = [
            StorageEmbraceLogExporter(
                logBatcher: DefaultLogBatcher(
                    repository: storage,
                    logLimits: .init(),
                    delegate: DummyLogBatcherDelegate.shared
                )
            )
        ]

        if let exporter = exporter {
            exporters.append(exporter)
        } 

        return DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            processors: .default(withExporters: exporters),
            resourceProvider: ResourceStorageExporter(storage: storage)
        )
    }
}

// TODO: This should go away. Simply added it to test the whole feature
import EmbraceCommon

class DummyLogBatcherDelegate: LogBatcherDelegate {
    static let shared = DummyLogBatcherDelegate()
    func batchFinished(withLogs logs: [LogRecord]) {
        ConsoleLog.info("BATCH FINISHEDDD", logs)
    }
}
