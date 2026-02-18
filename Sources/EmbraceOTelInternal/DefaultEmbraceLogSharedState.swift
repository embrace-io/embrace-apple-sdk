////
////  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
////
//
//import Foundation
//import OpenTelemetrySdk
//
//#if !EMBRACE_COCOAPOD_BUILDING_SDK
//    import EmbraceCommonInternal
//#endif
//
//class DefaultEmbraceLogSharedState: EmbraceLogSharedState {
//    let processors: [LogRecordProcessor]
//    private(set) var config: any EmbraceLoggerConfig
//
//    init(
//        config: any EmbraceLoggerConfig,
//        processors: [LogRecordProcessor],
//    ) {
//        self.config = config
//        self.processors = processors
//    }
//
//    func update(_ config: any EmbraceLoggerConfig) {
//        self.config = config
//    }
//}
//
//extension DefaultEmbraceLogSharedState {
//    static func create(
//        storage: EmbraceStorage,
//        batcher: LogBatcher,
//        processors: [LogRecordProcessor] = [],
//        exporter: LogRecordExporter? = nil,
//        sdkStateProvider: EmbraceSDKStateProvider,
//        resource: Resource? = nil
//    ) -> DefaultEmbraceLogSharedState {
//
//        let exporters = exporter != nil ? [exporter!] : []
//
//        return DefaultEmbraceLogSharedState(
//            config: DefaultEmbraceLoggerConfig(),
//            processors: .default(processors: processors, exporters: exporters, sdkStateProvider: sdkStateProvider),
//            resourceProvider: ResourceStorageExporter(storage: storage, resource: resource)
//        )
//    }
//}
