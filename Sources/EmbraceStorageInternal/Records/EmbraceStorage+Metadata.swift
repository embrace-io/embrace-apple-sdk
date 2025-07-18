//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import CoreData

public protocol EmbraceStorageMetadataFetcher: AnyObject {
    func fetchAllResources() -> [EmbraceMetadata]
    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata]
    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata]
    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata]
    func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata]
    func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata]
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
    ) -> EmbraceMetadata? {

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

        if let metadata = MetadataRecord.create(
            context: coreData.context,
            key: key,
            value: value,
            type: type,
            lifespan: lifespan,
            lifespanId: lifespanId
        ) {
            coreData.save()
            return metadata
        }

        return nil
    }

    /// Adds or updates all the given required resources
    public func addRequiredResources(_ map: [String: String], processId: ProcessIdentifier = .current) {
        
        coreData.performOperation { context in

            guard let description = NSEntityDescription.entity(forEntityName: MetadataRecord.entityName, in: context) else {
                logger.error("Error finding entity description for MetadataRecord!")
                return
            }

            for (key, value) in map {
                // find if exists
                let request = MetadataRecord.createFetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(
                    format: "key == %@ AND typeRaw == %@ AND lifespanRaw == %@ AND lifespanId == %@",
                    key,
                    MetadataRecordType.requiredResource.rawValue,
                    MetadataRecordLifespan.process.rawValue,
                    processId.hex
                )

                var record: MetadataRecord?
                do {
                    record = try context.fetch(request).first
                } catch {
                    logger.error("Error fetching required resource \(key)!")
                }

                // update
                if let record = record {
                    record.value = value

                // create
                } else {
                    record = MetadataRecord(entity: description, insertInto: context)
                    record?.key = key
                    record?.value = value
                    record?.typeRaw = MetadataRecordType.requiredResource.rawValue
                    record?.lifespanRaw = MetadataRecordLifespan.process.rawValue
                    record?.lifespanId = processId.hex
                    record?.collectedAt = Date()
                }
            }
            coreData.save()
        }
    }

    func fetchMetadataRequest(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = ""
    ) -> NSFetchRequest<MetadataRecord> {

        let request = MetadataRecord.createFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "key == %@ AND typeRaw == %@ AND lifespanRaw == %@ AND lifespanId == %@",
            key,
            type.rawValue,
            lifespan.rawValue,
            lifespanId
        )

        return request
    }

    func fetchMetadata(request: NSFetchRequest<MetadataRecord>, context: NSManagedObjectContext) -> MetadataRecord? {
        do {
            return try context.fetch(request).first
        } catch {
            logger.error("Error fetching existing metadata!:\n\(error.localizedDescription)")
        }

        return nil
    }

    /// Returns an immutable copy of the `MetadataRecord` for the given values.
    public func fetchMetadata(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = ""
    ) -> EmbraceMetadata? {
        coreData.performOperation { context in
            // fetch existing metadata
            let request = fetchMetadataRequest(key: key, type: type, lifespan: lifespan, lifespanId: lifespanId)
            guard let metadata = fetchMetadata(request: request, context: context) else {
                return nil
            }

            return metadata.toImmutable()
        }
    }

    /// Updates the `MetadataRecord` for the given key, type and lifespan with a new given value.
    /// - Returns: Immutable copy of the updated record, if any
    @discardableResult
    public func updateMetadata(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String
    ) -> EmbraceMetadata? {
        coreData.performOperation(save: true) { context in
            // fetch existing metadata
            let request = fetchMetadataRequest(key: key, type: type, lifespan: lifespan, lifespanId: lifespanId)
            guard let metadata = fetchMetadata(request: request, context: context) else {
                return nil
            }
            metadata.value = value
            return metadata.toImmutable()
        }
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

        coreData.deleteRecords(withRequest: request)
    }

    /// Removes the `MetadataRecord` for the given values.
    public func removeMetadata(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String
    ) {
        let request = fetchMetadataRequest(key: key, type: type, lifespan: lifespan, lifespanId: lifespanId)
        coreData.deleteRecords(withRequest: request)
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

        coreData.deleteRecords(withRequest: request)
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

        coreData.deleteRecords(withRequest: request)
    }

    /// Returns the permanent required resource for the given key.
    public func fetchRequiredPermanentResource(key: String) -> EmbraceMetadata? {
        return fetchMetadata(key: key, type: .requiredResource, lifespan: .permanent)
    }

    /// Increments the numeric value by 1 of a permanent resource for the given key.
    /// If no record exists it will create one with a value of 1.
    public func incrementCountForPermanentResource(key: String) -> Int {
        coreData.performOperation(save: true) { context in
            // fetch existing metadata
            let request = fetchMetadataRequest(key: key, type: .requiredResource, lifespan: .permanent)

            // update it if it exists
            if let metadata = fetchMetadata(request: request, context: context) {
                let val = (Int(metadata.value) ?? 0) + 1
                metadata.value = String(val)
                return val
            // create it with a value of 1 if it doesn't exist
            } else {
                let val = 1
                _ = MetadataRecord.create(
                    context: context,
                    key: key,
                    value: String(val),
                    type: .requiredResource,
                    lifespan: .permanent,
                    lifespanId: ""
                )
                return val
            }
        }
    }

    /// Returns immutable copies of all records with types `.requiredResource` or `.resource`
    public func fetchAllResources() -> [EmbraceMetadata] {
        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSPredicate(
            format: "typeRaw == %@ OR typeRaw == %@",
            MetadataRecordType.resource.rawValue,
            MetadataRecordType.requiredResource.rawValue
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records with types `.requiredResource` or `.resource` that are tied to a given session id
    public func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {

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

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records with types `.requiredResource` or `.resource` that are tied to a given process id
    public func fetchResourcesForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                resourcePredicate(),
                lifespanPredicate(processId: processId)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records of the `.customProperty` type that are tied to a given session id
    public func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
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

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records of the `.personaTag` type that are tied to a given session id
    public func fetchPersonaTagsForSessionId(_ sessionId: SessionIdentifier) -> [EmbraceMetadata] {
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

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records of the `.personaTag` type that are tied to a given process id
    public func fetchPersonaTagsForProcessId(_ processId: ProcessIdentifier) -> [EmbraceMetadata] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                personaTagPredicate(),
                lifespanPredicate(processId: processId)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
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

    private func lifespanPredicate(session: EmbraceSession) -> NSPredicate {
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
