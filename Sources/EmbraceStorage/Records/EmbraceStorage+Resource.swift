//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

// MARK: - Sync resource operations
extension EmbraceStorage {

    @discardableResult public func addResource(key: String, value: String, resourceType: ResourceType, resourceTypeId: String = "N/A") throws -> ResourceRecord {
        let resource = ResourceRecord(key: key, value: value, resourceType: resourceType, resourceTypeId: resourceTypeId)
        try self.upsertResource(resource)
        return resource
    }

    @discardableResult public func addResource(key: String, value: Int, resourceType: ResourceType, resourceTypeId: String = "N/A") throws -> ResourceRecord {
        let resource = ResourceRecord(key: key, value: value, resourceType: resourceType, resourceTypeId: resourceTypeId)
        try self.upsertResource(resource)
        return resource
    }

    @discardableResult public func addResource(key: String, value: Double, resourceType: ResourceType, resourceTypeId: String = "N/A") throws -> ResourceRecord {
        let resource = ResourceRecord(key: key, value: value, resourceType: resourceType, resourceTypeId: resourceTypeId)
        try self.upsertResource(resource)
        return resource
    }

    public func upsertResource(_ resource: ResourceRecord) throws {
        try dbQueue.write { [weak self] db in
            try self?.upsertResource(db: db, resource: resource)
        }
    }

    public func fetchResource(key: String) throws -> ResourceRecord? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchResource(db: db, key: key)
        }
    }

    public func fetchResource(sessionId: String) throws -> [ResourceRecord]? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchResource(db: db, sessionId: sessionId)
        }
    }

    public func fetchResource(pId: Int32) throws -> [ResourceRecord]? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchResource(db: db, pId: pId)
        }
    }

    public func fetchAllResources()throws -> [ResourceRecord]? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchAllResources(db: db)
        }
    }

    public func fetchAllPermanentResources()throws -> [ResourceRecord]? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchPermanentResources(db: db)
        }
    }

    public func fetchAllResourceForSession(sessionId: String) throws -> [ResourceRecord]? {
        try dbQueue.read { [weak self] db in
            return try self?.fetchAllResourceForSession(db: db, sessionId: sessionId)
        }
    }
}

// MARK: - Async session operations
extension EmbraceStorage {
    public func upsertResourceAsync(
        _ resource: ResourceRecord,
        completion: ((Result<ResourceRecord, Error>) -> Void)?) throws {

            dbWriteAsync(block: { [weak self] db in
                try self?.upsertResource(db: db, resource: resource)
                return resource
            }, completion: completion)
        }

    public func fetchResourceAsync(
        key: String,
        completion: @escaping (Result<ResourceRecord?, Error>) -> Void) {

        dbFetchOneAsync(block: { [weak self] db in
            return try self?.fetchResource(db: db, key: key)
        }, completion: completion)
    }

    public func fetchResourceAsync(
        sessionId: String,
        completion: @escaping ((Result<[ResourceRecord], Error>) -> Void)) {

        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchResource(db: db, sessionId: sessionId) ?? []
        }, completion: completion)
    }

    public func fetchResourceAsync(
        pId: Int32,
        completion: @escaping ((Result<[ResourceRecord], Error>) -> Void)) {

        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchResource(db: db, pId: pId) ?? []
        }, completion: completion)
    }

    public func fetchPermanentResourcesAsync(
    completion: @escaping ((Result<[ResourceRecord], Error>) -> Void)) {
        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchPermanentResources(db: db) ?? []
        }, completion: completion)
    }

    public func fetchAllResourceForSessionAsync(
        sessionId: String,
        completion: @escaping ((Result<[ResourceRecord], Error>) -> Void)) {
        dbFetchAsync(block: { [weak self] db in
            return try self?.fetchAllResourceForSession(db: db, sessionId: sessionId) ?? []
        }, completion: completion)
    }
}

// MARK: - DB Operations
fileprivate extension EmbraceStorage {
    func upsertResource(db: Database, resource: ResourceRecord) throws {
        try resource.insert(db)
    }

    func fetchAllResources(db: Database) throws -> [ResourceRecord] {
        return try ResourceRecord.fetchAll(db)
    }

    func fetchResource(db: Database, key: String) throws -> ResourceRecord? {
        return try ResourceRecord.fetchOne(db, sql: "SELECT * FROM resources WHERE key='\(key)'")
    }

    func fetchResource(db: Database, sessionId: String) throws -> [ResourceRecord]? {
        return try ResourceRecord.fetchAll(db, sql: "SELECT * FROM resources WHERE resource_type='session' and resource_type_id='\(sessionId)'")
    }

    func fetchResource(db: Database, pId: Int32) throws -> [ResourceRecord]? {
        return try ResourceRecord.fetchAll(db, sql: "SELECT * FROM resources WHERE resource_type='process' and resource_type_id='\(pId)'")
    }

    func fetchPermanentResources(db: Database) throws -> [ResourceRecord]? {
        return try ResourceRecord.fetchAll(db, sql: "SELECT * FROM resources WHERE resource_type='permanent'")
    }

    func fetchAllResourceForSession(db: Database, sessionId: String) throws -> [ResourceRecord]? {
        return try ResourceRecord.fetchAll(db, sql: "SELECT * from sessions RIGHT OUTER JOIN resources ON (resources.resource_type='session' AND resources.resource_type_id=sessions.id) OR resources.resource_type='permanent' OR (resources.resource_type='process' AND resources.resource_type_id=sessions.process_id) WHERE sessions.id='\(sessionId)'")
    }
}
