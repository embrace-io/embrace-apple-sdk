//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

public extension Array where Element == any LogRecordProcessor {
    static func `default`(
        withExporters exporters: [LogRecordExporter]
    ) -> [LogRecordProcessor] {
        [SingleLogRecordProcessor(exporters: exporters)]
    }
}
