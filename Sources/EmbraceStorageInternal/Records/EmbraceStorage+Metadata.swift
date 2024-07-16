//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB
import EmbraceCommonInternal

public protocol EmbraceStorageMetadataFetcher: AnyObject {
    func fetchAllResources() throws -> [MetadataRecord]
    func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord]
    func fetchResourcesForProcessId(_ processId: ProcessIdentifier) throws -> [MetadataRecord]

    func fetchAllCustomProperties() throws -> [MetadataRecord]
    func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord]
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
    ) throws -> MetadataRecord? {

        let metadata = MetadataRecord(
            key: key,
            value: .string(value),
            type: type,
            lifespan: lifespan,
            lifespanId: lifespanId
        )

        if try addMetadata(metadata) {
            return metadata
        }

        return nil
    }

    /// Adds a new `MetadataRecord`.
    /// Fails and returns nil if the metadata limit was reached.
    public func addMetadata(_ metadata: MetadataRecord) throws -> Bool {
        try dbQueue.write { db in

            // required resources are always inserted
            if metadata.type == .requiredResource {
                try metadata.insert(db)
                return true
            }

            // check limit for the metadata type
            // only records of the same type with the same lifespan id
            // or permanent records of the same type
            // this means a resource will not count towards the custom property limit, and viceversa
            // this also means metadata from other sessions/processes will not count for the limit either

            let limit = metadata.type == .resource ? options.resourcesLimit : options.customPropertiesLimit
            let count = try MetadataRecord.filter(
                MetadataRecord.Schema.type == metadata.type.rawValue &&
                (MetadataRecord.Schema.lifespan == MetadataRecordLifespan.permanent.rawValue ||
                 MetadataRecord.Schema.lifespanId == metadata.lifespanId)
            ).fetchCount(db)

            guard count < limit else {
                // TODO: limit could be applied incorrectly if at max limit and updating an existing record
                return false
            }

            try metadata.insert(db)
            return true
        }
    }

    /// Updates the `MetadataRecord` for the given key, type and lifespan with a new given value.
    public func updateMetadata(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan
    ) throws {

        try dbQueue.write { db in
            guard var record = try MetadataRecord
                .filter(
                    MetadataRecord.Schema.key == key &&
                    MetadataRecord.Schema.type == type.rawValue &&
                    MetadataRecord.Schema.lifespan == lifespan.rawValue
                )
                    .fetchOne(db) else {
                return
            }

            record.value = .string(value)
            try record.update(db)
        }
    }

    /// Updates the given `MetadataRecord`.
    public func updateMetadata(_ record: MetadataRecord) throws {
        try dbQueue.write { db in
            try record.update(db)
        }
    }

    /// Removes all `MetadataRecords` that don't corresponde to the given session and process ids.
    /// Permanent metadata is not removed.
    public func cleanMetadata(
        currentSessionId: String?,
        currentProcessId: String
    ) throws {
        _ = try dbQueue.write { db in
            if let currentSessionId = currentSessionId {
                try MetadataRecord.filter(
                    (MetadataRecord.Schema.lifespan == MetadataRecordLifespan.session.rawValue &&
                     MetadataRecord.Schema.lifespanId != currentSessionId) ||
                    (MetadataRecord.Schema.lifespan == MetadataRecordLifespan.process.rawValue &&
                     MetadataRecord.Schema.lifespanId != currentProcessId)
                )
                .deleteAll(db)
            } else {
                try MetadataRecord.filter(
                    MetadataRecord.Schema.lifespan == MetadataRecordLifespan.process.rawValue &&
                    MetadataRecord.Schema.lifespanId != currentProcessId
                )
                .deleteAll(db)
            }
        }
    }

    /// Removes the `MetadataRecord` for the given values.
    public func removeMetadata(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = ""
    ) throws {
        try dbQueue.write { db in
            guard let record = try MetadataRecord
                .filter(
                    MetadataRecord.Schema.key == key &&
                    MetadataRecord.Schema.type == type.rawValue &&
                    MetadataRecord.Schema.lifespan == lifespan.rawValue &&
                    MetadataRecord.Schema.lifespanId == lifespanId
                )
                .fetchOne(db) else {
                return
            }

            try record.delete(db)
        }
    }

    /// Removes all `MetadataRecords` for the given lifespans.
    /// Note that this method is inteded to be indirectly used by implementers of the SDK
    /// For this reason records of the `.requiredResource` type are not removed.
    public func removeAllMetadata(type: MetadataRecordType, lifespans: [MetadataRecordLifespan]) throws {
        guard type != .requiredResource && lifespans.count > 0 else {
            return
        }

        try dbQueue.write { db in
            let request = MetadataRecord.filter(MetadataRecord.Schema.type == type.rawValue)

            var expressions: [SQLExpression] = []
            for lifespan in lifespans {
                expressions.append(MetadataRecord.Schema.lifespan == lifespan.rawValue)
            }

            try request
                .filter(expressions.joined(operator: .or))
                .deleteAll(db)
        }
    }

    /// Removes all `MetadataRecords` for the given keys and timespan.
    /// Note that this method is inteded to be indirectly used by implementers of the SDK
    /// For this reason records of the `.requiredResource` type are not removed.
    public func removeAllMetadata(keys: [String], lifespan: MetadataRecordLifespan) throws {
        guard keys.count > 0 else {
            return
        }

        try dbQueue.write { db in
            let request = MetadataRecord.filter(
                MetadataRecord.Schema.type != MetadataRecordType.requiredResource.rawValue
            )

            var expressions: [SQLExpression] = []
            for key in keys {
                expressions.append(MetadataRecord.Schema.key == key)
            }

            try request
                .filter(expressions.joined(operator: .or))
                .deleteAll(db)
        }
    }

    /// Returns the `MetadataRecord` for the given values.
    public func fetchMetadata(
        key: String,
        type: MetadataRecordType,
        lifespan: MetadataRecordLifespan,
        lifespanId: String = ""
    ) throws -> MetadataRecord? {

        try dbQueue.read { db in
            return try MetadataRecord
                .filter(
                    MetadataRecord.Schema.key == key &&
                    MetadataRecord.Schema.type == type.rawValue &&
                    MetadataRecord.Schema.lifespan == lifespan.rawValue &&
                    MetadataRecord.Schema.lifespanId == lifespanId
                )
                .fetchOne(db)
        }
    }

    /// Returns the permanent required resource for the given key.
    public func fetchRequriedPermanentResource(key: String) throws -> MetadataRecord? {
        return try fetchMetadata(key: key, type: .requiredResource, lifespan: .permanent)
    }

    /// Returns all records with types `.requiredResource` or `.resource`
    public func fetchAllResources() throws -> [MetadataRecord] {
        try dbQueue.read { db in
            return try resourcesFilter().fetchAll(db)
        }
    }

    /// Returns all records with types `.requiredResource` or `.resource` that are tied to a given session id
    public func fetchResourcesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        try dbQueue.read { db in
            guard let session = try SessionRecord.fetchOne(db, key: sessionId.toString) else {
                return []
            }

            return try resourcesFilter()
                .filter(
                    (
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.session.rawValue &&
                        MetadataRecord.Schema.lifespanId == session.id.toString
                    ) || (
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.process.rawValue &&
                        MetadataRecord.Schema.lifespanId == session.processId.hex
                    ) ||
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.permanent.rawValue
                )
                .fetchAll(db)
        }
    }

    /// Returns all records with types `.requiredResource` or `.resource` that are tied to a given process id
    public func fetchResourcesForProcessId(_ processId: ProcessIdentifier) throws -> [MetadataRecord] {
        try dbQueue.read { db in

            return try resourcesFilter()
                .filter(
                    (
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.process.rawValue &&
                        MetadataRecord.Schema.lifespanId == processId.hex
                    ) ||
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.permanent.rawValue
                )
                .fetchAll(db)
        }
    }

    /// Returns all records of the `.customProperty` type
    public func fetchAllCustomProperties() throws -> [MetadataRecord] {
        try dbQueue.read { db in
            return try customPropertiesFilter().fetchAll(db)
        }
    }

    /// Returns all records of the `.customProperty` type that are tied to a given session id
    public func fetchCustomPropertiesForSessionId(_ sessionId: SessionIdentifier) throws -> [MetadataRecord] {
        try dbQueue.read { db in
            guard let session = try SessionRecord.fetchOne(db, key: sessionId.toString) else {
                return []
            }

            return try customPropertiesFilter()
                .filter(
                    (
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.session.rawValue &&
                        MetadataRecord.Schema.lifespanId == session.id.toString
                    ) || (
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.process.rawValue &&
                        MetadataRecord.Schema.lifespanId == session.processId.hex
                    ) ||
                        MetadataRecord.Schema.lifespan == MetadataRecordLifespan.permanent.rawValue
                )
                .fetchAll(db)
        }
    }
}

extension EmbraceStorage {
    private func resourcesFilter() -> QueryInterfaceRequest<MetadataRecord> {
        return MetadataRecord.filter(
            MetadataRecord.Schema.type == MetadataRecordType.requiredResource.rawValue ||
            MetadataRecord.Schema.type == MetadataRecordType.resource.rawValue)
    }

    private func customPropertiesFilter() -> QueryInterfaceRequest<MetadataRecord> {
        return MetadataRecord.filter(MetadataRecord.Schema.type == MetadataRecordType.customProperty.rawValue)
    }
}
