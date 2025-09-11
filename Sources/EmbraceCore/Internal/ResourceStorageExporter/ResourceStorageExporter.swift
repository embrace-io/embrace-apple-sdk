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
#endif

class ConcreteEmbraceResource: EmbraceResource {
    var key: String
    var value: ResourceValue

    init(key: String, value: ResourceValue) {
        self.key = key
        self.value = value
    }
}

class ResourceStorageExporter: EmbraceResourceProvider {
    private(set) weak var storage: EmbraceStorage?

    public init(storage: EmbraceStorage) {
        self.storage = storage
    }

    func getResource() -> Resource {
        guard let storage = storage else {
            return Resource()
        }

        let records = storage.fetchAllResources()

        var attributes: [String: AttributeValue] = records.reduce(into: [:]) { partialResult, record in
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

        return Resource(attributes: attributes)
    }
}
