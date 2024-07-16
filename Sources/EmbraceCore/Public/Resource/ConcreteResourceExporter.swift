//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal
import EmbraceStorageInternal

public class ConcreteResourceExporter: EmbraceResourceProvider {
    private let internalExporter: EmbraceResourceProvider
    private let blockedKeys: [String]

    private static let embracePrefix = "emb."

    internal init(_ internalExporter: EmbraceResourceProvider,
                  blockedKeys: [String] = []) {
        self.internalExporter = internalExporter
        self.blockedKeys = blockedKeys
    }

    public func getResources() -> [EmbraceResource] {
        return internalExporter.getResources()
            .filter {
                !blockedKeys.contains($0.key)
            }.map {
                removeEmbracePrefix(fromResource: $0)
            }
    }

    private func removeEmbracePrefix(fromResource resource: EmbraceResource) -> EmbraceResource {
        guard resource.key.hasPrefix(Self.embracePrefix) else {
            return resource
        }
        let newKey = String(resource.key.dropFirst(Self.embracePrefix.count))
        return ConcreteEmbraceResource(key: newKey, value: resource.value)
    }
}

// MARK: Factory
public extension ConcreteResourceExporter {
    static func create(storage: EmbraceStorage) -> ConcreteResourceExporter {
        ConcreteResourceExporter(ResourceStorageExporter(storage: storage))
    }
}
