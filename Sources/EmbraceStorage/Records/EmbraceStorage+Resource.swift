//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

public protocol EmbraceStorageResourceFetcher {
    func fetchAllResourceForSession(sessionId: String) throws -> [ResourceRecord]?
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

    public func fetchResource(key: String) throws -> ResourceRecord? {
        try dbQueue.read { db in
            return try ResourceRecord
                .filter(Column("key") == key)
                .fetchOne(db)
        }
    }

    public func fetchAllResources()throws -> [ResourceRecord]? {
        try dbQueue.read { db in
            return try ResourceRecord.fetchAll(db)
        }
    }

    public func fetchAllResourceForSession(sessionId: String) throws -> [ResourceRecord]? {
        try dbQueue.read { db in
            return try ResourceRecord.fetchAll(db, sql: "SELECT * from sessions RIGHT OUTER JOIN resources ON (resources.resource_type='session' AND resources.resource_type_id=sessions.id) OR resources.resource_type='permanent' OR (resources.resource_type='process' AND resources.resource_type_id=sessions.process_id) WHERE sessions.id='\(sessionId)'")
        }
    }
}
