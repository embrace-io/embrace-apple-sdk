//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceCommonInternal
#endif

extension Collection where Element == SpanProcessor {
    static func processors(
        for storage: EmbraceStorage,
        sessionController: SessionControllable,
        export: OpenTelemetryExport?,
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> [SpanProcessor] {
        var processors: [SpanProcessor] = [
            SingleSpanProcessor(
                spanExporter: StorageSpanExporter(
                    options: .init(storage: storage, sessionController: sessionController),
                    logger: Embrace.logger
                ),
                sdkStateProvider: sdkStateProvider
            )
        ]

        if let external = export?.spanExporter {
            processors.append(
                BatchSpanProcessor(spanExporter: external) { [weak storage] items in
                    let resource = getResource(storage: storage)
                    for idx in items.indices {
                        items[idx].settingResource(resource)
                    }
                })
        }

        return processors
    }

    static func getResource(storage: EmbraceStorage?) -> Resource {
        guard let storage = storage else {
            return Resource()
        }
        let provider = ResourceStorageExporter(storage: storage)
        return provider.getResource()
    }
}
