//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension Embrace {
    /// Resource keys set by the SDK's app and device info capture services.
    /// These can't be added or overwritten by the resources passed when starting the SDK, nor through `addResources(_:)`.
    static let reservedResourceKeys: Set<String> = Set(
        AppResourceKey.allCases.map(\.rawValue) + DeviceResourceKey.allCases.map(\.rawValue)
    )

    func addOtelResources() {
        guard let otelResources else {
            return
        }

        for (key, value) in otelResources {
            guard !Embrace.reservedResourceKeys.contains(key) else {
                Embrace.logger.warning("Resource \(key) is reserved by the SDK and can't be overwritten!")
                continue
            }

            metadata.addMetadata(key: key, value: value.description, type: .requiredResource, lifespan: .process)
        }
    }

    /// Adds the given resources to the current process.
    /// Every payload uploaded afterwards includes them.
    /// Resources with a key reserved by the SDK are dropped and a warning is logged.
    /// - Note: This method has no effect if the SDK is disabled.
    package func addResources(_ resources: [String: String]) {
        guard isSDKEnabled else {
            return
        }

        for (key, value) in resources {
            guard !Embrace.reservedResourceKeys.contains(key) else {
                Embrace.logger.warning("Resource \(key) is reserved by the SDK and can't be overwritten!")
                continue
            }

            metadata.addMetadata(key: key, value: value, type: .resource, lifespan: .process)
        }
    }
}
