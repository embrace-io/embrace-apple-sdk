//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
import EmbraceCommonInternal

public class CoreDataWrapper {

    public let options: CoreDataWrapper.Options

    var container: NSPersistentContainer!
    public private(set) var context: NSManagedObjectContext!

    let logger: InternalLogger
    let lock = NSLock()

    public init(options: CoreDataWrapper.Options, logger: InternalLogger) throws {
        self.options = options
        self.logger = logger

        // create model
        let model = NSManagedObjectModel()
        model.entities = options.entities

        // create container
        let name = options.storageMechanism.name
        self.container = NSPersistentContainer(name: name, managedObjectModel: model)

        switch options.storageMechanism {
        case .inMemory:
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            self.container.persistentStoreDescriptions = [description]

        case let .onDisk(_, baseURL):
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let description = NSPersistentStoreDescription()
            description.type = NSSQLiteStoreType
            description.url = options.storageMechanism.fileURL
            self.container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                logger.error("Error initializing CoreData \"\(name)\": \(error.localizedDescription)")
            }
        }

        self.context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.context.persistentStoreCoordinator = self.container.persistentStoreCoordinator
    }

    /// Removes the database file
    /// - Note: Only used in tests!!!
    public func destroy() {
#if canImport(XCTest)
        lock.withLock {
            context.performAndWait {

                context.reset()

                switch options.storageMechanism {
                case .onDisk:
                    if let url = options.storageMechanism.fileURL {
                        do {
                            try container.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType)
                            try FileManager.default.removeItem(at: url)
                        } catch {
                            logger.error("Error destroying CoreData stack!:\n\(error.localizedDescription)")
                        }
                    }

                default: return
                }

                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    do {
                        try container.persistentStoreCoordinator.remove(store)
                    } catch {
                        logger.error("Error removing CoreData store!:\n\(error.localizedDescription)")
                    }
                }

                container = nil
                context = nil
            }
        }
#endif
    }

    /// Synchronously saves all changes on the current context to disk
    public func save() {
        lock.withLock {
            context.performAndWait { [weak self] in
                do {
                    try self?.context.save()
                } catch {
                    let name = self?.context.name ?? "???"
                    self?.logger.warning("Error saving CoreData \"\(name)\": \(error.localizedDescription)")
                }
            }
        }
    }

    /// Synchronously fetches the records that satisfy the given request
    public func fetch<T>(withRequest request: NSFetchRequest<T>) -> [T] where T: NSManagedObject {
        return lock.withLock {

            var result: [T] = []
            context.performAndWait {
                do {
                    result = try context.fetch(request)
                } catch { }
            }
            return result
        }
    }

    /// Synchronously fetches the count of records that satisfy the given request
    public func count<T>(withRequest request: NSFetchRequest<T>) -> Int where T: NSManagedObject {
        return lock.withLock {

            var result: Int = 0
            context.performAndWait {
                do {
                    result = try context.count(for: request)
                } catch { }
            }
            return result
        }
    }

    /// Synchronously deletes record from the database and saves
    public func deleteRecord<T>(_ record: T) where T: NSManagedObject {
        deleteRecords([record])
    }

    /// Synchronously deletes requested records from the database and saves
    public func deleteRecords<T>(_ records: [T]) where T: NSManagedObject {
        lock.withLock {
            context.performAndWait { [weak self] in
                for record in records {
                    self?.context.delete(record)
                }
                
                try? self?.context.save()
            }
        }
    }
}
