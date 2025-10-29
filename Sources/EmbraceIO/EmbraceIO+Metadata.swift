//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// User QoL accessors
extension EmbraceIO {

    /// Set a 'name' for the current user.
    /// Will be set permanently until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the identifier. Be sure it matches or can be mapped to a record in your system
    var userName: String? {
        get {
            Embrace.client?.metadata.userName
        }
        set {
            Embrace.client?.metadata.userName = newValue
        }
    }

    /// Set a 'email' for the current user.
    /// Will be set permanently until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the username. Be sure it matches or can be mapped to a record in your system
    public var userEmail: String? {
        get {
            Embrace.client?.metadata.userEmail
        }
        set {
            Embrace.client?.metadata.userEmail = newValue
        }
    }

    /// Set an 'identifier' for the current user.
    /// Will be set permanently  until explicitly unset via the `clearUserProperties()` method.
    /// - Note: No validation is done on the email address. Be sure it matches or can be mapped to a record in your system
    var userIdentifier: String? {
        get {
            Embrace.client?.metadata.userIdentifier
        }
        set {
            Embrace.client?.metadata.userIdentifier = newValue
        }
    }

    /// Clear all user properties.
    /// This will clear all user properties set via the `userName`, `userEmail` and `userIdentifier` properties.
    func clearUserProperties() {
        Embrace.client?.metadata.clearUserProperties()
    }
}

/// Session properties
extension EmbraceIO {

    /// Adds or removes a property with the given key, value and lifespan.
    /// If there are 2 properties with the same key but different lifespans, the one with a shorter lifespan will be used.
    /// - Parameters:
    ///   - key: The key of the property to add. Can not be longer than 128 characters.
    ///   - value: The value of the property to add. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the property to add.
    /// - Throws: `MetadataError.invalidKey` if the key is longer than 128 characters.
    /// - Throws: `MetadataError.invalidSession` if a property with a `.session` lifespan is added when there's no active session.
    func setProperty(key: String, value: String?, lifespan: MetadataLifespan) throws {
        if let value {
            try Embrace.client?.metadata.addProperty(key: key, value: value, lifespan: lifespan)
        } else {
            try Embrace.client?.metadata.removeProperty(key: key, lifespan: lifespan)
        }
    }

    /// Removes all properties for the given lifespans. If no lifespans are passed, all properties are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    func removeAllProperties(lifespans: [MetadataLifespan]) {
        Embrace.client?.metadata.removeAllProperties(lifespans: lifespans)
    }
}

/// Personas
extension EmbraceIO {
    /// Adds a persona tag with the given value and lifespan.
    /// - Parameters:
    ///   - value: The value of the persona tag to add.
    ///   - lifespan: The lifespan of the persona tag to add.
    /// - Throws: `MetadataError.invalidValue` if the value is longer than 32 characters.
    /// - Throws: `MetadataError.invalidSession` if a persona tag with a `.session` lifespan is added when there's no active session.
    func addPersona(_ persona: String, lifespan: MetadataLifespan) throws {
        try Embrace.client?.metadata.add(persona: persona, lifespan: lifespan)
    }

    /// Removes a persona tag in the given lifespan.
    /// - Parameters:
    ///   - value: The value of the persona tag to remove.
    ///   - lifespan: The lifespan of the persona tag to remove.
    /// - Throws: `MetadataError.invalidSession` if a persona tag with a `.session` lifespan is added when there's no active session.
    /// - Note: It is only possible to remove personas/metadata from the currently active session or process. It is not possible to edit
    /// metadata that belongs to a session or process that has ended. If you remove a persona with a process
    /// lifespan and that persona has already been applied to a previous session within the process, that metadata
    /// will apply to that earlier session but will not apply to the currently active session.
    func removePersona(_ persona: String, lifespan: MetadataLifespan) throws {
        try Embrace.client?.metadata.remove(persona: persona, lifespan: lifespan)
    }

    /// Removes all persona tags for the given lifespans. If no lifespans are passed, all persona tags are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    func removeAllPersonas(lifespans: [MetadataLifespan]) {
        Embrace.client?.metadata.removeAllPersonas(lifespans: lifespans)
    }

    /// Asynchronously retrieve the current set of persona tags as strings.
    ///
    /// - Note: This method is for Objective-C compatibility. In Swift, there's an equivalent using the `PersonaTag` enum
    func getCurrentPersonas(completion: @escaping ([String]) -> Void) {
        guard let client = Embrace.client else {
            completion([])
            return
        }

        client.metadata.getCurrentPersonas(completion: completion)
    }
}
