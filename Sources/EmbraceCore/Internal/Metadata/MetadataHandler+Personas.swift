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
    package func getCurrentPersonas(completion: @escaping ([String]) -> Void) {
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
    /// If the persona tag is too long or no session is active for a `.session` lifespan, the persona is dropped and a warning is logged.
    /// - Parameters:
    ///   - value: The value of the persona tag to add.
    ///   - lifespan: The lifespan of the persona tag to add.
    package func add(persona: String, lifespan: MetadataLifespan = .session) {
        guard persona.count <= Self.maxPersonaTagLength else {
            Embrace.logger.warning(
                "Failed to add persona: the persona tag length can not be greater than \(Self.maxPersonaTagLength)"
            )
            return
        }

        addMetadata(
            key: persona,
            value: "",
            type: .personaTag,
            lifespan: lifespan
        )
    }

    /// Removes the persona tag for the given value and lifespan.
    /// If no session is active for a `.session` lifespan, the removal is dropped and a warning is logged.
    /// - Parameters:
    ///   - value: The key of the persona tag to remove.
    ///   - lifespan: The lifespan of the persona tag to remove. This was declared when this persona was added.
    ///
    /// It is only possible to remove personas/metadata from the currently active session or process. It is not possible to edit
    /// metadata that belongs to a session or process that has ended. If you remove a persona with a process
    /// lifespan and that persona has already been applied to a previous session within the process, that metadata
    /// will apply to that earlier session but will not apply to the currently active session.
    package func remove(persona: String, lifespan: MetadataLifespan) {
        remove(key: persona, type: .personaTag, lifespan: lifespan)
    }

    /// Removes all persona tags for the given lifespans. If no lifespans are passed, all persona tags are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    package func removeAllPersonas(lifespans: [MetadataLifespan] = [.permanent, .process, .session]) {
        removeAll(type: .personaTag, lifespans: lifespans)
    }
}
