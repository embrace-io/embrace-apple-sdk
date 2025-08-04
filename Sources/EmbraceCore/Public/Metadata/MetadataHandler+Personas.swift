//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
#endif

extension MetadataHandler {

    /// Retrieve the current set of persona tags.
    ///
    /// - Important: We strongly advise against calling this method from the main thread,
    /// as it may block the UI. Use `getCurrentPersonas(completion:)` instead.
    @available(*, deprecated, message: "Use `getCurrentPersonas(completion:)` instead.")
    public var currentPersonas: [PersonaTag] {
        guard let storage = storage else {
            return []
        }

        var records: [EmbraceMetadata] = []
        if let sessionId = sessionController?.currentSession?.id {
            records = storage.fetchPersonaTagsForSessionId(sessionId)
        } else {
            records = storage.fetchPersonaTagsForProcessId(ProcessIdentifier.current)
        }

        return records.map { PersonaTag($0.key) }
    }

    /// Fetch the current set of persona tags.
    ///
    /// - Parameter completion: A closure that receives the list of persona tags.
    public func getCurrentPersonas(completion: @escaping ([PersonaTag]) -> Void) {
        guard let storage = self.storage else {
            completion([])
            return
        }

        self.synchronizationQueue.async {
            var records: [EmbraceMetadata] = []
            if let sessionId = self.sessionController?.currentSession?.id {
                records = storage.fetchPersonaTagsForSessionId(sessionId)
            } else {
                records = storage.fetchPersonaTagsForProcessId(ProcessIdentifier.current)
            }

            let tags = records.map { PersonaTag($0.key) }
            completion(tags)
        }
    }

    /// Adds a persona tag with the given value and lifespan.
    /// - Parameters:
    ///   - value: The value of the persona tag to add.
    ///   - lifespan: The lifespan of the persona tag to add.
    /// - Throws: `MetadataError.invalidValue` if the value is longer than 32 characters.
    /// - Throws: `MetadataError.invalidSession` if a persona tag with a `.session` lifespan is added when there's no active session.
    public func add(persona: PersonaTag, lifespan: MetadataLifespan = .session) throws {
        try persona.validate()
        try addMetadata(
            key: persona.rawValue,
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: lifespan
        )
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
    public func removeAllPersonas(lifespans: [MetadataLifespan] = [.permanent, .process, .session]) {
        removeAll(type: .personaTag, lifespans: lifespans)
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
    ///
    /// - Important: We strongly advise against calling this method from the main thread,
    /// as it may block the UI. Use `fetchCurrentPersonas(completion:)` instead.
    @available(*, deprecated, message: "Use `getCurrentPersonas(completion:)` instead.")
    @objc public func getCurrentPersonas() -> [String] {
        currentPersonas.map(\.rawValue)
    }

    /// Asynchronously retrieve the current set of persona tags as strings.
    ///
    /// - Note: This method is for Objective-C compatibility. In Swift, there's an equivalent using the `PersonaTag` enum
    @objc public func getCurrentPersonas(completion: @escaping ([String]) -> Void) {
        getCurrentPersonas { personaTags in
            completion(personaTags.map(\.rawValue))
        }
    }
}
