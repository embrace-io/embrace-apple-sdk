//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
public typealias EmbraceLogRecordProcessor = LogRecordProcessor

public extension Array where Element == any EmbraceLogRecordProcessor {
    static func `default`(
        withExporters exporters: [EmbraceLogRecordExporter]
    ) -> [EmbraceLogRecordProcessor] {
        [SingleLogRecordProcessor(exporters: exporters)]
    }
}
