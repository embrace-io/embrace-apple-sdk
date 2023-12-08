//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

import EmbraceStorage

public final class UserResource {

    /// Set a 'username' for the current user
    /// Will be set permanently until explicitly unset via the ``clear`` method
    /// - Note: No validation is done on the username. Be sure it matches or
    ///         can be mapped to a record in your system
    var username: String? {
        get {
            value(for: .username)
        }
        set {
            update(key: .username, value: newValue)
        }
    }

    /// Set an 'email' for the current user
    /// Will be set permanently  until explicitly unset via the ``clear`` method
    /// - Note: No validation is done on the email address. Be sure it matches or
    ///         can be mapped to a record in your system
    var email: String? {
        get {
            value(for: .email)
        }
        set {
            update(key: .email, value: newValue)
        }
    }

    /// Set a 'identifier' for the current user
    /// Will be set permanently until explicitly unset via the ``clear`` method
    /// - Note: No validation is done on the identifier. Be sure it matches or
    ///         can be mapped to a record in your system
    var identifier: String? {
        get {
            value(for: .identifier)
        }
        set {
            update(key: .identifier, value: newValue)
        }
    }

    private weak var storage: EmbraceStorage?

    init(storage: EmbraceStorage) {
        self.storage = storage
    }

    /// Clear all user attributes.
    ///
    /// This will clear all user attributes set via the ``username``, ``email``, and ``identifier`` properties
    public func clear() {
        guard let storage = storage else {
            return
        }

        do {
            try storage.removePermanentResources(keys: UserResourceKey.allValues)
        } catch {
            // TODO: log warning
        }
    }

}

extension UserResource {

    /// Retrieve value from EmbraceStorage
    private func value(for key: UserResourceKey) -> String? {
        guard let storage = storage else {
            return nil
        }

        do {
            let record = try storage.fetchPermanentResource(key: key.rawValue)
            return record?.value
        } catch {
            // TODO: log warning
        }
        return nil
    }

    /// Set value in EmbraceStorage
    private func update(key: UserResourceKey, value: String?) {
        guard let storage = storage else {
            return
        }

        if let value = value {
            do {
                let record = ResourceRecord(key: key.rawValue, value: value)
                try storage.upsertResource(record)
            } catch {
                // TODO: log warning
            }
        } else {
            remove(key)
        }
    }

    /// Remove value in EmbraceStorage
    private func remove(_ key: UserResourceKey) {
        guard let storage = storage else {
            return
        }

        do {
            try storage.removePermanentResources(keys: [key.rawValue])
        } catch {
            print("An error occurred when removing this user resource key: \(key)")
        }
    }

}
