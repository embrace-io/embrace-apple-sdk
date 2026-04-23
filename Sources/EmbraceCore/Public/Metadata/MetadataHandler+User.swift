//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

extension MetadataHandler {

    /// Set a 'identifier' for the current user.
    /// Pass nil to remove.
    /// - Note: No validation is done on the identifier. Be sure it matches or
    ///         can be mapped to a record in your system
    package var userIdentifier: String? {
        get {
            value(for: .identifier)
        }
        set {
            synchronizationQueue.async {
                self.update(key: .identifier, value: newValue)
            }
        }
    }
}

extension MetadataHandler {

    private func value(for key: UserResourceKey) -> String? {
        let record = storage?.fetchMetadata(key: key.rawValue, type: .customProperty, lifespan: .permanent)
        return record?.value
    }

    private func update(key: UserResourceKey, value: String?) {
        if let value = value {
            do {
                try addProperty(key: key.rawValue, value: value, lifespan: .permanent)
            } catch {
                Embrace.logger.warning("Unable to update user metadata!")
            }
        } else {
            remove(key)
        }
    }

    private func remove(_ key: UserResourceKey) {
        do {
            try remove(key: key.rawValue, type: .customProperty, lifespan: .permanent)
        } catch {
            Embrace.logger.warning("An error occurred when removing this user resource key: \(key)")
        }
    }
}
