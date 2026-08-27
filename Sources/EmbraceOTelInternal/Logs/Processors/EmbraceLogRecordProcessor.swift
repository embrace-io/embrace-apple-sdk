//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension Array where Element == any LogRecordProcessor {
    public static func `default`(
        processors: [LogRecordProcessor] = [],
        exporters: [LogRecordExporter] = [],
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> [LogRecordProcessor] {
        [SingleLogRecordProcessor(processors: processors, exporters: exporters, sdkStateProvider: sdkStateProvider)]
    }
}
