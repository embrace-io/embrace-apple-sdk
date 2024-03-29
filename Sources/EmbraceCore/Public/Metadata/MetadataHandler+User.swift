//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage

extension MetadataHandler {

    /// Set a 'name' for the current user.
    /// Will be set permanently until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the username. Be sure it matches or
    ///         can be mapped to a record in your system
    public var userName: String? {
        get {
            value(for: .name)
        }
        set {
            update(key: .name, value: newValue)
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
            update(key: .email, value: newValue)
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
            update(key: .identifier, value: newValue)
        }
    }

    /// Clear all user properties.
    /// This will clear all user properties set via the `userName`, `userEmail` and `userIdentifier` properties.
    @objc public func clearUserProperties() {
        do {
            try storage?.removeAllMetadata(keys: UserResourceKey.allValues, lifespan: .permanent)
        } catch {
            ConsoleLog.warning("Unable to clear user metadata")
        }
    }
}

extension MetadataHandler {

    private func value(for key: UserResourceKey) -> String? {
        do {
            let record = try storage?.fetchMetadata(key: key.rawValue, type: .resource, lifespan: .permanent)
            return record?.stringValue
        } catch {
            ConsoleLog.warning("Unable to read user metadata!")
        }
        return nil
    }

    private func update(key: UserResourceKey, value: String?) {
        if let value = value {
            do {
                try storage?.updateMetadata(
                    key: key.rawValue,
                    value: value,
                    type: .customProperty,
                    lifespan: .permanent
                )
            } catch {
                ConsoleLog.warning("Unable to update user metadata!")
            }
        } else {
            remove(key)
        }
    }

    private func remove(_ key: UserResourceKey) {
        do {
            try storage?.removeMetadata(key: key.rawValue, type: .customProperty, lifespan: .permanent)
        } catch {
            ConsoleLog.warning("An error occurred when removing this user resource key: \(key)")
        }
    }
}
