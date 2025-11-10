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

extension Embrace {

    // MARK: - Span Processor Pipeline

    /// Builds the ordered list of span processors used by the Embrace SDK.
    ///
    /// This method assembles the processor pipeline responsible for exporting and processing spans
    /// during runtime. It ensures the Embrace storage exporter is always first in the chain, followed
    /// by any custom exporters or processors supplied by the integrator.
    ///
    /// The resulting list defines the core export behavior for all tracing data recorded by the SDK.
    ///
    /// - Parameters:
    ///   - storage: The internal storage interface responsible for persisting spans.
    ///   - sessionController: Provides access to the current session for contextual export decisions.
    ///   - customExporter: An optional `OpenTelemetryExport` to forward spans to external systems.
    ///   - customProcessors: Optional list of additional `SpanProcessor` instances to append.
    ///   - sdkStateProvider: The provider of SDK runtime state, used to determine export behavior.
    ///   - useNewStorageForSpanEvents: Boolean flag to control whether to use new storage for span events.
    ///
    /// - Returns: An ordered, array of span processors. The Embrace storage processor
    ///   always appears first, followed by any user-supplied processors.
    internal func buildProcessors(
        for storage: EmbraceStorage,
        sessionController: SessionControllable,
        customExporter: OpenTelemetryExport? = nil,
        customProcessors: [any SpanProcessor]? = nil,
        sdkStateProvider: EmbraceSDKStateProvider,
        useNewStorageForSpanEvents: Bool
    ) -> [any SpanProcessor] {

        // Base Embrace exporter used by everything.
        let embraceStorageExporter = StorageSpanExporter(
            storage: storage,
            logger: Embrace.logger,
            useNewStorage: useNewStorageForSpanEvents
        )

        // Construct the exporter list, ensuring Embrace is first.
        let combinedExporters: [any SpanExporter] = {
            guard let exporter = customExporter?.spanExporter else {
                return [embraceStorageExporter]
            }
            return [embraceStorageExporter, exporter]
        }()

        // The core processor that dispatches completed spans to all exporters.
        let baseProcessor = EmbraceSpanProcessor(
            spanExporters: combinedExporters,
            sdkStateProvider: sdkStateProvider,
            logger: Embrace.logger,
            sessionIdProvider: { sessionController.currentSession?.idRaw },
            criticalResourceGroup: captureServicesGroup,
            resourceProvider: { ResourceStorageExporter(storage: storage).getResource() }
        )

        // Combine with any custom processors.
        return [baseProcessor] + (customProcessors ?? [])
    }
}
