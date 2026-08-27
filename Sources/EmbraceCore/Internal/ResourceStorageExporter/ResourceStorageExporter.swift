//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceObjCUtilsInternal
    import EmbraceStorageInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

class ResourceStorageExporter: EmbraceResourceProvider {
    private(set) weak var storage: EmbraceStorage?
    private(set) var resource: Resource?

    /// Resources that are stored as such only so they survive a process boundary, and that must not
    /// be reported as resource attributes. Experiments travel as an attribute of the session span and
    /// of each log instead.
    private static let excludedKeys: Set<String> = [SpanSemantics.keyExperiments]

    public init(storage: EmbraceStorage, resource: Resource? = nil) {
        self.storage = storage
        self.resource = resource
    }

    func getResource() -> Resource {
        guard let storage = storage else {
            return resource ?? Resource()
        }

        let records = storage.fetchResourcesForExport()

        var attributes: [String: AttributeValue] = records.reduce(into: [:]) { partialResult, record in
            guard !Self.excludedKeys.contains(record.key) else {
                return
            }
            partialResult[record.key] = .string(record.value)
        }

        if attributes[SemanticConventions.Service.name.rawValue] == nil {
            let serviceName = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
                .compactMap { $0 }
                .joined(separator: ":")

            attributes[SemanticConventions.Service.name.rawValue] = .string(serviceName)
        }

        if attributes[SemanticConventions.Service.version.rawValue] == nil, let appVersion = EMBDevice.appVersion {
            attributes[SemanticConventions.Service.version.rawValue] = .string(appVersion)
        }

        if attributes[SemanticConventions.Telemetry.sdkLanguage.rawValue] == nil {
            attributes[SemanticConventions.Telemetry.sdkLanguage.rawValue] = .string("swift")
        }

        var finalResources = Resource(attributes: attributes)

        // if the user passed custom resources, those take priority
        if let resource = resource {
            finalResources.merge(other: resource)
        }

        return finalResources
    }
}
