//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// User QoL accessors
extension EmbraceIO {

    /// Set an 'identifier' for the current user.
    /// Pass nil to remove.
    /// - Note: No validation is done on the email address. Be sure it matches or can be mapped to a record in your system
    public var userIdentifier: String? {
        get {
            Embrace.client?.metadata.userIdentifier
        }
        set {
            Embrace.client?.metadata.userIdentifier = newValue
        }
    }
}

/// Session properties
extension EmbraceIO {

    /// Adds or removes a property with the given key, value and lifespan.
    /// If there are 2 properties with the same key but different lifespans, the one with a shorter lifespan will be used.
    /// If the key is too long or no session is active for a `.session` lifespan, the property is dropped and a warning is logged.
    /// - Parameters:
    ///   - key: The key of the property to add. Can not be longer than 128 characters.
    ///   - value: The value of the property to add. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the property to add.
    public func setProperty(key: String, value: String?, lifespan: MetadataLifespan) {
        if let value {
            Embrace.client?.metadata.addProperty(key: key, value: value, lifespan: lifespan)
        } else {
            Embrace.client?.metadata.removeProperty(key: key, lifespan: lifespan)
        }
    }

    /// Removes all properties for the given lifespans. If no lifespans are passed, all properties are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllProperties(lifespans: [MetadataLifespan]) {
        Embrace.client?.metadata.removeAllProperties(lifespans: lifespans)
    }
}

/// Personas
extension EmbraceIO {
    /// Adds a persona tag with the given value and lifespan.
    /// If the persona tag is too long or no session is active for a `.session` lifespan, the persona is dropped and a warning is logged.
    /// - Parameters:
    ///   - value: The value of the persona tag to add.
    ///   - lifespan: The lifespan of the persona tag to add.
    public func addPersona(_ persona: String, lifespan: MetadataLifespan) {
        Embrace.client?.metadata.add(persona: persona, lifespan: lifespan)
    }

    /// Removes a persona tag in the given lifespan.
    /// If no session is active for a `.session` lifespan, the removal is dropped and a warning is logged.
    /// - Parameters:
    ///   - value: The value of the persona tag to remove.
    ///   - lifespan: The lifespan of the persona tag to remove.
    /// - Note: It is only possible to remove personas/metadata from the currently active session or process. It is not possible to edit
    /// metadata that belongs to a session or process that has ended. If you remove a persona with a process
    /// lifespan and that persona has already been applied to a previous session within the process, that metadata
    /// will apply to that earlier session but will not apply to the currently active session.
    public func removePersona(_ persona: String, lifespan: MetadataLifespan) {
        Embrace.client?.metadata.remove(persona: persona, lifespan: lifespan)
    }

    /// Removes all persona tags for the given lifespans. If no lifespans are passed, all persona tags are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllPersonas(lifespans: [MetadataLifespan]) {
        Embrace.client?.metadata.removeAllPersonas(lifespans: lifespans)
    }

    /// Asynchronously retrieve the current set of persona tags as strings.
    public func getCurrentPersonas(completion: @escaping ([String]) -> Void) {
        guard let client = Embrace.client else {
            completion([])
            return
        }

        client.metadata.getCurrentPersonas(completion: completion)
    }
}
