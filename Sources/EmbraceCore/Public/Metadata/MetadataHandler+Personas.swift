//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceStorageInternal
    import EmbraceCommonInternal
#endif

extension MetadataHandler {

    /// Fetch the current set of persona tags.
    ///
    /// - Parameter completion: A closure that receives the list of persona tags.
    public func getCurrentPersonas(completion: @escaping ([String]) -> Void) {
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

            let tags = records.map { $0.key }
            completion(tags)
        }
    }

    /// Adds a persona tag with the given value and lifespan.
    /// - Parameters:
    ///   - value: The value of the persona tag to add.
    ///   - lifespan: The lifespan of the persona tag to add.
    /// - Throws: `MetadataError.invalidValue` if the value is longer than 32 characters.
    /// - Throws: `MetadataError.invalidSession` if a persona tag with a `.session` lifespan is added when there's no active session.
    public func add(persona: String, lifespan: MetadataLifespan = .session) throws {
        guard persona.count <= Self.maxPersonaTagLength else {
            throw MetadataError.invalidValue(
                "The persona tag length can not be greater than \(Self.maxPersonaTagLength)"
            )
        }

        try addMetadata(
            key: persona,
            value: "",
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
    public func remove(persona: String, lifespan: MetadataLifespan) throws {
        try remove(key: persona, type: .personaTag, lifespan: lifespan)
    }

    /// Removes all persona tags for the given lifespans. If no lifespans are passed, all persona tags are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllPersonas(lifespans: [MetadataLifespan] = [.permanent, .process, .session]) {
        removeAll(type: .personaTag, lifespans: lifespans)
    }
}
