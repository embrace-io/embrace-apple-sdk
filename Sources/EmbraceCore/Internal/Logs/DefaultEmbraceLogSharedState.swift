//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal
import EmbraceStorageInternal
import EmbraceCommonInternal
import OpenTelemetrySdk

class DefaultEmbraceLogSharedState: EmbraceLogSharedState {
    let processors: [LogRecordProcessor]
    let resourceProvider: EmbraceResourceProvider
    private(set) var config: any EmbraceLoggerConfig

    init(
        config: any EmbraceLoggerConfig,
        processors: [LogRecordProcessor],
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
        batcher: LogBatcher,
        exporter: LogRecordExporter? = nil,
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> DefaultEmbraceLogSharedState {
        var exporters: [LogRecordExporter] = [
            StorageEmbraceLogExporter(
                logBatcher: batcher
            )
        ]

        if let exporter = exporter {
            exporters.append(exporter)
        }

        return DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            processors: .default(withExporters: exporters, sdkStateProvider: sdkStateProvider),
            resourceProvider: ResourceStorageExporter(storage: storage)
        )
    }
}
