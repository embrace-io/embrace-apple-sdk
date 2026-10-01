//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension Array where Element == any LogRecordProcessor {
    /// - Parameters:
    ///   - embraceExporters: Embrace's own exporters. They run inline on the emitting thread
    ///     so logs reach storage in the order they were emitted.
    ///   - processors: Customer processors. They run on a serial queue owned by the SDK.
    ///   - exporters: Customer exporters. They run on the same serial queue as `processors`.
    public static func `default`(
        embraceExporters: [LogRecordExporter] = [],
        processors: [LogRecordProcessor] = [],
        exporters: [LogRecordExporter] = [],
        sdkStateProvider: EmbraceSDKStateProvider
    ) -> [LogRecordProcessor] {
        var result: [LogRecordProcessor] = [
            SingleLogRecordProcessor(exporters: embraceExporters, sdkStateProvider: sdkStateProvider)
        ]

        if !processors.isEmpty || !exporters.isEmpty {
            let customerProcessor = SingleLogRecordProcessor(
                processors: processors,
                exporters: exporters,
                sdkStateProvider: sdkStateProvider
            )
            result.append(QueuedLogRecordProcessor(processor: customerProcessor))
        }

        return result
    }
}
