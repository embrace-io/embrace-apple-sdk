//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB
import EmbraceCommon

public protocol EmbraceStorageResourceFetcher {
    func fetchAllResourceForSession(sessionId: SessionIdentifier) throws -> [ResourceRecord]?
    func fetchAllResources()throws -> [ResourceRecord]?
}

// MARK: - Sync resource operations
extension EmbraceStorage: EmbraceStorageResourceFetcher {
    @discardableResult public func addResource(key: String, value: String, resourceType: ResourceType, resourceTypeId: String = "") throws -> ResourceRecord {
        let resource = ResourceRecord(key: key, value: value, resourceType: resourceType, resourceTypeId: resourceTypeId)
        try upsertResource(resource)
        return resource
    }

    public func upsertResource(_ resource: ResourceRecord) throws {
        try dbQueue.write { db in
            try resource.insert(db)
        }
    }

    public func upsertResources(_ resources: [ResourceRecord]) throws {
        try dbQueue.write { db in
            for resource in resources {
                try resource.insert(db)
            }
        }
    }

    public func fetchAllResources()throws -> [ResourceRecord]? {
        try dbQueue.read { db in
            return try ResourceRecord.fetchAll(db)
        }
    }

    public func fetchAllResourceForSession(sessionId: SessionIdentifier) throws -> [ResourceRecord]? {
        try dbQueue.read { db in
            return try ResourceRecord.fetchAll(
                db,
                sql: """
                    SELECT * from sessions RIGHT OUTER JOIN resources ON (resources.resource_type='session' AND resources.resource_type_id=sessions.id) OR resources.resource_type='permanent' OR (resources.resource_type='process' AND resources.resource_type_id=sessions.process_id) WHERE sessions.id=?
                """,
                arguments: StatementArguments([sessionId]))
        }
    }

    public func fetchAllResourceForSession(sessionId: SessionIdentifier, processId: ProcessIdentifier) throws -> [ResourceRecord]? {
        try dbQueue.read { db in
            let sessionResources = (Column("resource_type") == "session" && Column("resource_type_id") == "\(sessionId)")
            let processResource = (Column("resource_type") == "process" && Column("resource_type_id") == "\(processId)")
            let permanent = (Column("resource_type") == "permanent")

            return try ResourceRecord.filter(
                sessionResources ||
                processResource ||
                permanent
            ).fetchAll(db)
        }
    }
}
