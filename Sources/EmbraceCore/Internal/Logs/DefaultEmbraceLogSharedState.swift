//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

class DefaultEmbraceLogSharedState: EmbraceLogSharedState {
    let processors: [EmbraceLogRecordProcessor]
    let resourceProvider: ResourceProvider
    private(set) var config: any EmbraceLoggerConfig

    init(
        config: any EmbraceLoggerConfig,
        processors: [EmbraceLogRecordProcessor],
        resourceProvider: ResourceProvider
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
    static func create() -> EmbraceLogSharedState {
        DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            // TODO: Add Exporters
            processors: .default(withExporters: []),
            // TODO: Add Real Provider
            resourceProvider: DummyResourceProvider())
    }
}

// TODO: Remove this and replace with a real implementation
fileprivate struct DummyResourceProvider: ResourceProvider {
    func getResources() -> [EmbraceResource] { [] }
}
