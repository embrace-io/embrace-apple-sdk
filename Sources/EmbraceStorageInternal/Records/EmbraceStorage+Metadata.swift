//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

public protocol EmbraceStorageMetadataFetcher: AnyObject {
    func fetchAllResources() -> [MetadataRecord]
    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord]
    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [MetadataRecord]
    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord]
    func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord]
    func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [MetadataRecord]
}

extension EmbraceStorage {

    /// Adds a new `MetadataRecord` with the given values.
    /// Fails and returns nil if the metadata limit was reached.
    @discardableResult
    public func addMetadata(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = ""
    ) -> MetadataRecord? {

        // update existing?
        if let metadata = updateMetadata(
            key: key,
            value: value,
            type: type,
            lifespan: lifespan,
            lifespanId: lifespanId
        ) {
            return metadata
        }

        // create new
        guard shouldAddMetadata(type: type, lifespanId: lifespanId) else {
            return nil
        }

        let metadata = MetadataRecord.create(
            context: coreData.context,
            key: key,
            value: value,
            type: type,
            lifespan: lifespan,
            lifespanId: lifespanId
        )

        coreData.save()

        return metadata
    }

    /// Returns the `MetadataRecord` for the given values.
    public func fetchMetadata(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = ""
    ) -> MetadataRecord? {

        let request = MetadataRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "key == %@ AND typeRaw == %@ AND lifespanRaw == %@ AND lifespanId == %@",
            key,
            type.rawValue,
            lifespan.rawValue,
            lifespanId
        )

        return coreData.fetch(withRequest: request).first
    }

    /// Updates the `MetadataRecord` for the given key, type and lifespan with a new given value.
    /// - Returns: The updated record, if any
    @discardableResult
    public func updateMetadata(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String
    ) -> MetadataRecord? {

        guard let metadata = fetchMetadata(key: key, type: type, lifespan: lifespan, lifespanId: lifespanId) else {
            return nil
        }

        metadata.value = value
        coreData.save()

        return metadata
    }

    /// Removes all `MetadataRecords` that don't correspond to the given session and process ids.
    /// Permanent metadata is not removed.
    public func cleanMetadata(currentSessionId: String?, currentProcessId: String) {
        let request = MetadataRecord.createFetchRequest()

        let processIdPredicate = NSPredicate(
            format: "lifespanRaw == %@ AND lifespanId != %@",
            MetadataRecordLifespan.process.rawValue,
            currentProcessId
        )

        if let currentSessionId = currentSessionId {
            let sessionIdPredicate = NSPredicate(
                format: "lifespanRaw == %@ AND lifespanId != %@",
                MetadataRecordLifespan.session.rawValue,
                currentSessionId
            )

            request.predicate = NSCompoundPredicate(type: .or, subpredicates: [sessionIdPredicate, processIdPredicate])
        } else {
            request.predicate = processIdPredicate
        }

        let records = coreData.fetch(withRequest: request)
        coreData.deleteRecords(records)
    }

    /// Removes the `MetadataRecord` for the given values.
    public func removeMetadata(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String
    ) {

        guard let metadata = fetchMetadata(key: key, type: type, lifespan: lifespan, lifespanId: lifespanId) else {
            return
        }

        coreData.deleteRecord(metadata)
    }

    /// Removes all `MetadataRecords` for the given type and lifespans.
    /// - Note: This method is inteded to be indirectly used by implementers of the SDK
    ///         For this reason records of the `.requiredResource` type are not removed.
    public func removeAllMetadata(type: MetadataRecordType, lifespans: [MetadataRecordLifespan]) {
        guard type != .requiredResource && lifespans.count > 0 else {
            return
        }

        let request = MetadataRecord.createFetchRequest()
        let typePredicate = NSPredicate(format: "typeRaw == %@", type.rawValue)

        var lifespanPredicates: [NSPredicate] = []
        for lifespan in lifespans {
            let predicate = NSPredicate(format: "lifespanRaw == %@", lifespan.rawValue)
            lifespanPredicates.append(predicate)
        }
        let lifespansPredicate = NSCompoundPredicate(type: .or, subpredicates: lifespanPredicates)

        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [typePredicate, lifespansPredicate])

        let records = coreData.fetch(withRequest: request)
        coreData.deleteRecords(records)
    }

    /// Removes all `MetadataRecords` for the given keys and timespan.
    /// - Note: This method is inteded to be indirectly used by implementers of the SDK
    ///         For this reason records of the `.requiredResource` type are not removed.
    public func removeAllMetadata(keys: [String], lifespan: MetadataRecordLifespan) {
        guard keys.count > 0 else {
            return
        }

        let request = MetadataRecord.createFetchRequest()
        let typePredicate = NSPredicate(format: "typeRaw != %@", MetadataRecordType.requiredResource.rawValue)

        var keyPredicates: [NSPredicate] = []
        for key in keys {
            let predicate = NSPredicate(format: "key == %@", key)
            keyPredicates.append(predicate)
        }
        let keyPredicate = NSCompoundPredicate(type: .or, subpredicates: keyPredicates)

        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [typePredicate, keyPredicate])

        let records = coreData.fetch(withRequest: request)
        coreData.deleteRecords(records)
    }

    /// Returns the permanent required resource for the given key.
    public func fetchRequiredPermanentResource(key: String) -> MetadataRecord? {
        return fetchMetadata(key: key, type: .requiredResource, lifespan: .permanent)
    }

    /// Returns all records with types `.requiredResource` or `.resource`
    public func fetchAllResources() -> [MetadataRecord] {
        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSPredicate(
            format: "typeRaw == %@ OR typeRaw == %@",
            MetadataRecordType.resource.rawValue,
            MetadataRecordType.requiredResource.rawValue
        )

        return coreData.fetch(withRequest: request)
    }

    /// Returns all records with types `.requiredResource` or `.resource` that are tied to a given session id
    public func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord] {

        guard let session = fetchSession(id: sessionId) else {
            return []
        }

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                resourcePredicate(),
                lifespanPredicate(session: session)
            ]
        )

        return coreData.fetch(withRequest: request)
    }

    /// Returns all records with types `.requiredResource` or `.resource` that are tied to a given process id
    public func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [MetadataRecord] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                resourcePredicate(),
                lifespanPredicate(processId: processId)
            ]
        )

        return coreData.fetch(withRequest: request)
    }

    /// Returns all records of the `.customProperty` type that are tied to a given session id
    public func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord] {
        guard let session = fetchSession(id: sessionId) else {
            return []
        }

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                customPropertyPredicate(),
                lifespanPredicate(session: session)
            ]
        )

        return coreData.fetch(withRequest: request)
    }

    /// Returns all records of the `.personaTag` type that are tied to a given session id
    public func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [MetadataRecord] {
        guard let session = fetchSession(id: sessionId) else {
            return []
        }

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                personaTagPredicate(),
                lifespanPredicate(session: session)
            ]
        )

        return coreData.fetch(withRequest: request)
    }

    /// Returns all records of the `.personaTag` type that are tied to a given process id
    public func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [MetadataRecord] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                personaTagPredicate(),
                lifespanPredicate(processId: processId)
            ]
        )

        return coreData.fetch(withRequest: request)
    }
}

extension EmbraceStorage {

    /// Adds a new `MetadataRecord`.
    /// Fails and returns nil if the metadata limit was reached.
    public func shouldAddMetadata(type: MetadataRecordType, lifespanId: String) -> Bool {

        // required resources are always inserted
        if type == .requiredResource {
            return true
        }

        // check limit for the metadata type
        // only records of the same type with the same lifespan id
        // or permanent records of the same type
        // this means a resource will not count towards the custom property limit, and viceversa
        // this also means metadata from other sessions/processes will not count for the limit either
        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSPredicate(
            format: "typeRaw == %@ AND (lifespanRaw == %@ OR lifespanId == %@)",
            type.rawValue,
            MetadataRecordLifespan.permanent.rawValue,
            lifespanId
        )

        let limit = limitForType(type)
        return coreData.count(withRequest: request) < limit
    }

    private func limitForType(_ type: MetadataRecordType) -> Int {
        switch type {
        case .resource: return options.resourcesLimit
        case .customProperty: return options.customPropertiesLimit
        case .personaTag: return options.personaTagsLimit
        default: return 0
        }
    }

    private func resourcePredicate() -> NSPredicate {
        return NSPredicate(
            format: "typeRaw == %@ OR typeRaw == %@",
            MetadataRecordType.resource.rawValue,
            MetadataRecordType.requiredResource.rawValue
        )
    }

    private func customPropertyPredicate() -> NSPredicate {
        return NSPredicate(format: "typeRaw == %@", MetadataRecordType.customProperty.rawValue)
    }

    private func personaTagPredicate() -> NSPredicate {
        return NSPredicate(format: "typeRaw == %@", MetadataRecordType.personaTag.rawValue)
    }

    private func lifespanPredicate(session: SessionRecord) -> NSPredicate {
        // match the session id
        let sessionIdPredicate = NSPredicate(
            format: "lifespanRaw == %@ AND lifespanId == %@",
            MetadataRecordLifespan.session.rawValue,
            session.idRaw
        )
        // or match the process id
        let processIdPredicate = NSPredicate(
            format: "lifespanRaw == %@ AND lifespanId == %@",
            MetadataRecordLifespan.process.rawValue,
            session.processIdRaw
        )
        // or are permanent
        let permanentPredicate = NSPredicate(
            format: "lifespanRaw == %@",
            MetadataRecordLifespan.permanent.rawValue
        )

        return NSCompoundPredicate(
            type: .or,
            subpredicates: [
                sessionIdPredicate,
                processIdPredicate,
                permanentPredicate
            ]
        )
    }

    private func lifespanPredicate(processId: ProcessIdentifier) -> NSPredicate {
        // match the process id
        let processIdPredicate = NSPredicate(
            format: "lifespanRaw == %@ AND lifespanId == %@",
            MetadataRecordLifespan.process.rawValue,
            processId.hex
        )
        // or are permanent
        let permanentPredicate = NSPredicate(
            format: "lifespanRaw == %@",
            MetadataRecordLifespan.permanent.rawValue
        )

        return NSCompoundPredicate(
            type: .or,
            subpredicates: [
                processIdPredicate,
                permanentPredicate
            ]
        )
    }

}
