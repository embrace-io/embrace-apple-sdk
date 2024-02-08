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
    static func create(storage: EmbraceStorage) -> DefaultEmbraceLogSharedState {
        DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            // TODO: Add Exporters
            processors: .default(withExporters: []),

            resourceProvider: ResourceStorageExporter(storage: storage))
    }
}
