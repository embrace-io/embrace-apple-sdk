//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
import EmbraceCommonInternal

public extension Array where Element == any LogRecordProcessor {
    static func `default`(
        withExporters exporters: [LogRecordExporter],
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> [LogRecordProcessor] {
        [SingleLogRecordProcessor(exporters: exporters, sdkStateProvider: sdkStateProvider)]
    }
}
