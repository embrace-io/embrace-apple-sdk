//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
import EmbraceStorageInternal
import EmbraceOTelInternal

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

    func getResources() -> [EmbraceResource] {

        guard let storage = storage else {
            return []
        }

        guard let resources = try? storage.fetchAllResources() else {
            return []
        }

        return resources.map {ConcreteEmbraceResource(key: $0.key, value: $0.value)}
    }
}
