//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal

extension MetadataHandler {

    /// Retrieve the current set of persona tags.
    public var currentPersonas: [PersonaTag] {
        guard let storage = storage else {
            return []
        }

        var records: [MetadataRecord] = []
        do {
            if let sessionId = sessionController?.currentSession?.id {
                records = try storage.fetchPersonaTagsForSessionId(sessionId)
            } else {
                records = try storage.fetchPersonaTagsForProcessId(ProcessIdentifier.current)
            }
        } catch {
            Embrace.logger.error("Error fetching persona tags!\n\(error.localizedDescription)")
        }

        return records.map { PersonaTag($0.key) }
    }

    /// Adds a persona tag with the given value and lifespan.
    /// - Parameters:
    ///   - value: The value of the persona tag to add.
    ///   - lifespan: The lifespan of the persona tag to add.
    /// - Throws: `MetadataError.invalidValue` if the value is longer than 32 characters.
    /// - Throws: `MetadataError.invalidSession` if a persona tag with a `.session` lifespan is added when there's no active session.
    /// - Throws: `MetadataError.limitReached` if the limit of persona tags was reached.
    public func add(persona: PersonaTag, lifespan: MetadataLifespan = .session) throws {
        try persona.validate()
        try addMetadata(key: persona.rawValue, value: PersonaTag.metadataValue, type: .personaTag, lifespan: lifespan)
    }

    /// Removes the persona tag for the given value and lifespan.
    /// - Parameters:
    ///   - value: The key of the persona tag to remove.
    ///   - lifespan: The lifespan of the persona tag to remove. This was declared when this persona was added.
    ///
    /// It is only possible to remove personas/metadata from the currently active session or process. It is not possible to edit
    /// metadata that belongs to a session or process that has ended. If you remove a persona with a process
    /// lifespan and that persona has already been applied to a previous session within the process, that metadata
    /// will apply to that earlier session but will not apply to the currently active session.
    public func remove(persona: PersonaTag, lifespan: MetadataLifespan) throws {
        try remove(key: persona.rawValue, type: .personaTag, lifespan: lifespan)
    }

    /// Removes all persona tags for the given lifespans. If no lifespans are passed, all persona tags are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllPersonas(lifespans: [MetadataLifespan] = [.permanent, .process, .session]) throws {
        try removeAll(type: .personaTag, lifespans: lifespans)
    }
}

extension MetadataHandler {
    /// Adds a persona tag with the given value and lifespan.
    /// - Parameters:
    ///  - persona The value of the persona tag to add.
    ///  - lifespan The lifespan of the persona tag to add.
    ///
    ///  See `MetadataHandler.add(personas: [PersonaTag])` for more information on behavior
    ///
    /// - Note: This method is for Objective-C compatibility. In Swift, it is
    /// recommended to use ``PersonaTag`` and define custom persona tags as static properties.
    @objc public func add(persona: String, lifespan: MetadataLifespan = .session) throws {
        try add(persona: PersonaTag(persona), lifespan: lifespan)
    }

    /// Retrieve the current set of persona tags as strings.
    ///
    /// - Note: This method is for Objective-C compatibility. In Swift, it is
    ///         recommended to use the `currentPersonaTags` property.
    @objc public func getCurrentPersonas() -> [String] {
        currentPersonas.map(\.rawValue)
    }
}
