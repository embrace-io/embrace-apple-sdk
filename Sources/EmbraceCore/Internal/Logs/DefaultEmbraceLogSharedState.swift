//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceCommonInternal
#endif

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
        processors: [LogRecordProcessor] = [],
        exporter: LogRecordExporter? = nil,
        sdkStateProvider: EmbraceSDKStateProvider,
        resource: Resource? = nil
    ) -> DefaultEmbraceLogSharedState {
        let embraceExporters: [LogRecordExporter] = [
            StorageEmbraceLogExporter(
                logBatcher: batcher
            )
        ]

        var exporters: [LogRecordExporter] = []
        if let exporter = exporter {
            exporters.append(exporter)
        }

        return DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            processors: .default(
                embraceExporters: embraceExporters,
                processors: processors,
                exporters: exporters,
                sdkStateProvider: sdkStateProvider
            ),
            resourceProvider: ResourceStorageExporter(storage: storage, resource: resource)
        )
    }
}
