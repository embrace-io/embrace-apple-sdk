//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Fetches the metadata that applies to a given scope.
///
/// The user session scoped methods take the process id as a separate parameter instead of deriving it
/// from the user session: a user session can span more than one process (it's reconstructed at cold
/// start and continues), so a user session id alone doesn't identify a process.
public protocol EmbraceStorageMetadataFetcher: AnyObject {
    func fetchAllResources() -> [EmbraceMetadata]
    func fetchResources(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata]
    func fetchCustomProperties(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata]
    func fetchPersonaTags(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata]
    func fetchResourcesForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata]
    func fetchPersonaTagsForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata]
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

    // Add critical or required resources.
    // WARNING: This MUST be run behind `.performOperation` or `.performAsynOperation`.
    private func _addResources(
        _ map: [String: String],
        allowMainQueue: Bool,
        context: NSManagedObjectContext,
        processId: EmbraceIdentifier = ProcessIdentifier.current
    ) {

        guard let description = NSEntityDescription.entity(forEntityName: MetadataRecord.entityName, in: context)
        else {
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
                processId.stringValue
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
                record?.lifespanId = processId.stringValue
                record?.collectedAt = Date()
            }
        }
        coreData.save(allowMainQueue: allowMainQueue)
    }

    /// Adds or updates all the given critical resources **synchronously**
    public func addCriticalResources(_ map: [String: String], processId: EmbraceIdentifier = ProcessIdentifier.current) {
        coreData.performOperation(allowMainQueue: true) { context in
            _addResources(map, allowMainQueue: true, context: context, processId: processId)
        }
    }

    /// Adds or updates all the given required resources **asynchronously**
    public func addRequiredResources(_ map: [String: String], processId: EmbraceIdentifier = ProcessIdentifier.current) {
        coreData.performAsyncOperation { [self] context in
            _addResources(map, allowMainQueue: true, context: context, processId: processId)
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
        coreData.performOperation(allowMainQueue: true) { context in
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

    /// Removes all `MetadataRecords` that no longer correspond to anything: user session metadata whose
    /// user session is neither stored nor active, and process metadata from processes with no stored
    /// session part. Permanent metadata is not removed.
    ///
    /// This is also what reaps metadata written before the `.userSession` lifespan was scoped to user
    /// sessions: those records hold a session part id in `lifespanId`, which is never in the keep set.
    ///
    /// - Parameter activeUserSessionId: The user session that is currently active, if any. It's kept
    ///   even when no stored session part references it yet, since the session parts of a user session
    ///   are deleted as soon as they're uploaded.
    public func cleanMetadata(activeUserSessionId: EmbraceIdentifier? = nil) {
        let sessions = fetchAllSessions()

        var userSessionIdSet = Set(sessions.compactMap { $0.userSessionId?.stringValue })
        if let activeUserSessionId = activeUserSessionId {
            userSessionIdSet.insert(activeUserSessionId.stringValue)
        }
        let userSessionIds = Array(userSessionIdSet)
        let processIds = Array(Set(sessions.map { $0.processId.stringValue }))

        let request = MetadataRecord.createFetchRequest()

        let sessionPredicate: NSPredicate
        if userSessionIds.isEmpty {
            sessionPredicate = NSPredicate(
                format: "lifespanRaw == %@",
                MetadataRecordLifespan.userSession.rawValue
            )
        } else {
            sessionPredicate = NSPredicate(
                format: "lifespanRaw == %@ AND NOT (lifespanId IN %@)",
                MetadataRecordLifespan.userSession.rawValue,
                userSessionIds
            )
        }

        let processPredicate: NSPredicate
        if processIds.isEmpty {
            processPredicate = NSPredicate(
                format: "lifespanRaw == %@",
                MetadataRecordLifespan.process.rawValue
            )
        } else {
            processPredicate = NSPredicate(
                format: "lifespanRaw == %@ AND NOT (lifespanId IN %@)",
                MetadataRecordLifespan.process.rawValue,
                processIds
            )
        }

        request.predicate = NSCompoundPredicate(type: .or, subpredicates: [sessionPredicate, processPredicate])
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
        guard type != .requiredResource && lifespans.isEmpty == false else {
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
        guard keys.isEmpty == false else {
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
    public func incrementCountForPermanentResource(key: String) -> EMBInt {
        coreData.performOperation(save: true) { context in
            // fetch existing metadata
            let request = fetchMetadataRequest(key: key, type: .requiredResource, lifespan: .permanent)

            // update it if it exists
            if let metadata = fetchMetadata(request: request, context: context) {
                let val = (EMBInt(metadata.value) ?? 0) + 1
                metadata.value = String(val)
                return val
                // create it with a value of 1 if it doesn't exist
            } else {
                let val: EMBInt = 1
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
        coreData.fetchAndPerform(withRequest: request) { records, _ in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records with types `.requiredResource` or `.resource` that are tied to a given user session id or process id
    public func fetchResources(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                resourcePredicate(),
                lifespanPredicate(userSessionId: userSessionId?.stringValue, processId: processId.stringValue)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records with types `.requiredResource` or `.resource` that apply to the given session part
    package func fetchResources(for part: EmbraceSession) -> [EmbraceMetadata] {
        return fetchResources(userSessionId: part.userSessionId, processId: part.processId)
    }

    /// Returns immutable copies of all records with types `.requiredResource` or `.resource` that are tied to a given process id
    public func fetchResourcesForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                resourcePredicate(),
                lifespanPredicate(processId: processId.stringValue)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records of the `.customProperty` type that are tied to a given user session id and process id
    public func fetchCustomProperties(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                customPropertyPredicate(),
                lifespanPredicate(userSessionId: userSessionId?.stringValue, processId: processId.stringValue)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records of the `.customProperty` type that apply to the given session part
    package func fetchCustomProperties(for part: EmbraceSession) -> [EmbraceMetadata] {
        return fetchCustomProperties(userSessionId: part.userSessionId, processId: part.processId)
    }

    /// Returns immutable copies of all records of the `.personaTag` type that are tied to a given user session id and process id
    public func fetchPersonaTags(userSessionId: EmbraceIdentifier?, processId: EmbraceIdentifier) -> [EmbraceMetadata] {
        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                personaTagPredicate(),
                lifespanPredicate(userSessionId: userSessionId?.stringValue, processId: processId.stringValue)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

            // convert to immutable structs
            result = records.map {
                $0.toImmutable()
            }
        }

        return result
    }

    /// Returns immutable copies of all records of the `.personaTag` type that apply to the given session part
    package func fetchPersonaTags(for part: EmbraceSession) -> [EmbraceMetadata] {
        return fetchPersonaTags(userSessionId: part.userSessionId, processId: part.processId)
    }

    /// Returns immutable copies of all records of the `.personaTag` type that are tied to a given process id
    public func fetchPersonaTagsForProcessId(_ processId: EmbraceIdentifier) -> [EmbraceMetadata] {

        let request = MetadataRecord.createFetchRequest()
        request.predicate = NSCompoundPredicate(
            type: .and,
            subpredicates: [
                personaTagPredicate(),
                lifespanPredicate(processId: processId.stringValue)
            ]
        )

        // fetch
        var result: [EmbraceMetadata] = []
        coreData.fetchAndPerform(withRequest: request) { records, _ in

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
        // this also means metadata from other user sessions/processes will not count for the limit either
        // note that a user session spans multiple session parts, so the limit is shared by all of them
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

    /// A `nil` `userSessionId` means the caller has no user session to match against (a session part
    /// stored before user sessions existed, or a scope with no active user session). In that case only
    /// process and permanent metadata can apply.
    private func lifespanPredicate(userSessionId: String?, processId: String) -> NSPredicate {
        var subpredicates: [NSPredicate] = []

        // match the user session id
        if let userSessionId = userSessionId {
            subpredicates.append(
                NSPredicate(
                    format: "lifespanRaw == %@ AND lifespanId == %@",
                    MetadataRecordLifespan.userSession.rawValue,
                    userSessionId
                )
            )
        }

        // or match the process id
        subpredicates.append(
            NSPredicate(
                format: "lifespanRaw == %@ AND lifespanId == %@",
                MetadataRecordLifespan.process.rawValue,
                processId
            )
        )

        // or are permanent
        subpredicates.append(
            NSPredicate(
                format: "lifespanRaw == %@",
                MetadataRecordLifespan.permanent.rawValue
            )
        )

        return NSCompoundPredicate(type: .or, subpredicates: subpredicates)
    }

    private func lifespanPredicate(processId: String) -> NSPredicate {
        // match the process id
        let processIdPredicate = NSPredicate(
            format: "lifespanRaw == %@ AND lifespanId == %@",
            MetadataRecordLifespan.process.rawValue,
            processId
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
