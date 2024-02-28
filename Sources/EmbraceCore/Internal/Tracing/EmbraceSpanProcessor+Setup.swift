//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel
import EmbraceStorage

extension Collection where Element == EmbraceSpanProcessor {
    static func processors(for storage: EmbraceStorage, export: OpenTelemetryExport?) -> [EmbraceSpanProcessor] {
        var processors: [EmbraceSpanProcessor] = [
            SingleSpanProcessor(spanExporter: StorageSpanExporter(options: .init(storage: storage)))
        ]

        if let external = export?.spanExporter {
            processors.append(SingleSpanProcessor(spanExporter: external))
        }
        return processors
    }
}
