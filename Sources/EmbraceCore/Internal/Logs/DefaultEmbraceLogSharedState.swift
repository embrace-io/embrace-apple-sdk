//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

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
    static func create() -> DefaultEmbraceLogSharedState {
        DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            // TODO: Add Exporters
            processors: .default(withExporters: []),
            // TODO: Add Real Provider
            resourceProvider: DummyResourceProvider())
    }
}

// TODO: Remove this and replace with a real implementation
private struct DummyResourceProvider: EmbraceResourceProvider {
    func getResources() -> [EmbraceResource] { [] }
}
