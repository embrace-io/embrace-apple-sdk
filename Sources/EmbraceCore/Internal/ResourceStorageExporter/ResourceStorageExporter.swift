//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceStorageInternal
import EmbraceOTelInternal
#endif
import OpenTelemetryApi
import OpenTelemetrySdk
@_implementationOnly import EmbraceObjCUtilsInternal

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

        if attributes[ResourceAttributes.serviceName.rawValue] == nil {
            let serviceName = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
                .compactMap { $0 }
                .joined(separator: ":")

            attributes[ResourceAttributes.serviceName.rawValue] = .string(serviceName)
        }

        if attributes[ResourceAttributes.serviceVersion.rawValue] == nil, let appVersion = EMBDevice.appVersion {
                attributes[ResourceAttributes.serviceVersion.rawValue] = .string(appVersion)
        }

        if attributes[ResourceAttributes.telemetrySdkLanguage.rawValue] == nil {
            attributes[ResourceAttributes.telemetrySdkLanguage.rawValue] = .string("swift")
        }

        return Resource(attributes: attributes)
    }
}
