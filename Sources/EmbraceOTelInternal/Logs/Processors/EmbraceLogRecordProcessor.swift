//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension Array where Element == any LogRecordProcessor {
    public static func `default`(
        withExporters exporters: [LogRecordExporter],
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> [LogRecordProcessor] {
        [SingleLogRecordProcessor(exporters: exporters, sdkStateProvider: sdkStateProvider)]
    }
}
