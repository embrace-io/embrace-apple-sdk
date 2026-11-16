//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension Embrace {
    func addOtelResources() {
        guard let otelResources else {
            return
        }

        for (key, value) in otelResources {
            metadata.addMetadata(key: key, value: value.description, type: .requiredResource, lifespan: .process)
        }
    }

    /// Adds the given resources to the current process.
    /// Every payload uploaded afterwards includes them.
    /// - Note: This method has no effect if the SDK is disabled.
    package func addResources(_ resources: [String: String]) {
        guard isSDKEnabled else {
            return
        }

        for (key, value) in resources {
            metadata.addMetadata(key: key, value: value, type: .resource, lifespan: .process)
        }
    }
}
