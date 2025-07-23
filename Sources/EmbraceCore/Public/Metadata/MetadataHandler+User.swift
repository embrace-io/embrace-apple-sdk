//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

@objc extension MetadataHandler {

    /// Set a 'name' for the current user.
    /// Will be set permanently until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the username. Be sure it matches or
    ///         can be mapped to a record in your system
    public var userName: String? {
        get {
            value(for: .name)
        }
        set {
            synchronizationQueue.async {
                self.update(key: .name, value: newValue)
            }
        }
    }

    /// Set an 'email' for the current user.
    /// Will be set permanently  until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the email address. Be sure it matches or
    ///         can be mapped to a record in your system
    public var userEmail: String? {
        get {
            value(for: .email)
        }
        set {
            synchronizationQueue.async {
                self.update(key: .email, value: newValue)
            }
        }
    }

    /// Set a 'identifier' for the current user.
    /// Will be set permanently until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the identifier. Be sure it matches or
    ///         can be mapped to a record in your system
    public var userIdentifier: String? {
        get {
            value(for: .identifier)
        }
        set {
            synchronizationQueue.async {
                self.update(key: .identifier, value: newValue)
            }
        }
    }

    /// Clear all user properties.
    /// This will clear all user properties set via the `userName`, `userEmail` and `userIdentifier` properties.
    public func clearUserProperties() {
        synchronizationQueue.async {
            self.storage?.removeAllMetadata(keys: UserResourceKey.allValues, lifespan: .permanent)
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
