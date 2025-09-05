//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
#endif

class DefaultEmbraceLogSharedState: EmbraceLogSharedState {
    let processors: [LogRecordProcessor]
    private(set) var config: any EmbraceLoggerConfig

    init(
        config: any EmbraceLoggerConfig,
        processors: [LogRecordProcessor],
    ) {
        self.config = config
        self.processors = processors
    }

    func update(_ config: any EmbraceLoggerConfig) {
        self.config = config
    }
}

extension DefaultEmbraceLogSharedState {
    static func create(
        exporter: LogRecordExporter? = nil,
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> DefaultEmbraceLogSharedState {

        let exporters = exporter != nil ? [exporter!] : []

        return DefaultEmbraceLogSharedState(
            config: DefaultEmbraceLoggerConfig(),
            processors: .default(withExporters: exporters, sdkStateProvider: sdkStateProvider)
        )
    }
}
