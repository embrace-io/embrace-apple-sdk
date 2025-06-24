//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

public class CoreDataWrapper {

    public let options: CoreDataWrapper.Options

    var container: NSPersistentContainer!
    public private(set) var context: NSManagedObjectContext!

    let logger: InternalLogger

    private let isTesting: Bool

    public init(options: CoreDataWrapper.Options, logger: InternalLogger) throws {
        self.options = options
        self.logger = logger
        self.isTesting = ProcessInfo.processInfo.isTesting

        // create model
        let model = NSManagedObjectModel()
        model.entities = options.entities

        // create container
        let name = options.storageMechanism.name
        self.container = NSPersistentContainer(name: name, managedObjectModel: model)

        // force db on memory during tests
        if isTesting {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            self.container.persistentStoreDescriptions = [description]

        } else {
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
                description.setValue("DELETE" as NSString, forPragmaNamed: "journal_mode")

                self.container.persistentStoreDescriptions = [description]
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                logger.critical("Error initializing CoreData \"\(name)\": \(error.localizedDescription)")
            }
        }

        self.context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.context.persistentStoreCoordinator = self.container.persistentStoreCoordinator
    }

    /// Removes the database file
    /// - Note: Only used in tests!!!
    public func destroy() {
        guard isTesting else {
            return
        }

        performOperation { _ in

            context.reset()

            switch options.storageMechanism {
            case .onDisk:
                if let url = options.storageMechanism.fileURL {
                    do {
                        try container.persistentStoreCoordinator.destroyPersistentStore(
                            at: url,
                            ofType: NSSQLiteStoreType
                        )
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        logger.critical("Error destroying CoreData stack!:\n\(error.localizedDescription)")
                    }
                }

            default: return
            }

            if let store = container.persistentStoreCoordinator.persistentStores.first {
                do {
                    try container.persistentStoreCoordinator.remove(store)
                } catch {
                    logger.critical("Error removing CoreData store!:\n\(error.localizedDescription)")
                }
            }

            container = nil
            context = nil
        }
    }

    /// Synchronously performs the given block on the current context.
    /// This will also create a background task to perform the operation.
    public func performOperation(_ name: String = #function, save: Bool = false, _ block: (NSManagedObjectContext) -> Void) {
        
        let saveBlock = { (context: NSManagedObjectContext) in
            guard save else { return }
            do {
                try context.save()
            } catch {
                self.logger.critical("""
                    CoreData save failed '\(context.name ?? "???")', 
                    error: \(error.localizedDescription), 
                    operation: \(name)
                    """
                )
            }
        }
        
        if options.enableBackgroundTasks == false {
            context.performAndWait {
                block(context)
                saveBlock(context)
            }
        } else {
            let taskName = options.storageMechanism.name + "_" + name
            withExtendedBackgroundLifetime(taskName) {
                context.performAndWait {
                    block(context)
                    saveBlock(context)
                }
            }
        }
    }

    /// Synchronously saves all changes on the current context to disk
    public func save() {
        performOperation(save: true) {_ in}
    }

    /// Synchronously fetches the records that satisfy the given request
    public func fetch<T>(withRequest request: NSFetchRequest<T>) -> [T] where T: NSManagedObject {

        var result: [T] = []
        performOperation { [weak self] context in
            guard let self else {
                return
            }

            do {
                result = try context.fetch(request)
            } catch {
                self.logger.critical("Error fetching!!!:\n\(error.localizedDescription)")
            }
        }
        return result
    }

    /// Synchronously fetches the records that satisfy the given request and calls the block with them.
    public func fetchAndPerform<T>(withRequest request: NSFetchRequest<T>, block: (([T]) -> Void)) where T: NSManagedObject {

        performOperation { [weak self] context in
            guard let self else {
                block([])
                return
            }

            do {
                let result = try context.fetch(request)
                block(result)
            } catch {
                self.logger.critical("Error fetching with perform!!!:\n\(error.localizedDescription)")
            }
        }
    }

    /// Synchronously fetches the first record that satisfy the given request and calls the block with it.
    public func fetchFirstAndPerform<T>(withRequest request: NSFetchRequest<T>, block: ((T?) -> Void)) where T: NSManagedObject {

        performOperation { [weak self] context in
            guard let self else {
                block(nil)
                return
            }

            do {
                let result = try context.fetch(request)
                block(result.first)
            } catch {
                self.logger.critical("Error fetching first with perform!!!:\n\(error.localizedDescription)")
            }
        }
    }

    /// Synchronously fetches the count of records that satisfy the given request.
    public func count<T>(withRequest request: NSFetchRequest<T>) -> Int where T: NSManagedObject {

        var result: Int = 0
        performOperation { [weak self] context in
            guard let self else {
                return
            }

            do {
                result = try context.count(for: request)
            } catch {
                self.logger.critical("Error fetching count!!!:\n\(error.localizedDescription)")
            }
        }
        return result
    }

    /// Synchronously deletes record from the database and saves.
    public func deleteRecord<T>(_ record: T) where T: NSManagedObject {
        deleteRecords([record])
    }

    /// Synchronously deletes requested records from the database and saves.
    public func deleteRecords<T>(_ records: [T]) where T: NSManagedObject {
        
        performOperation(save: true) { [weak self] context in
            guard let self else {
                return
            }

            for record in records {
                context.delete(record)
            }
        }
    }

    /// Synchronously deletes requested records that satisfy the given request from the database and saves.
    public func deleteRecords<T>(withRequest request: NSFetchRequest<T>)where T: NSManagedObject {
        
        performOperation(save: true) { [weak self] context in
            guard let self else {
                return
            }

            do {
                let records = try context.fetch(request)
                for record in records {
                    context.delete(record)
                }
            } catch {
                self.logger.critical("Error deleting records with request:\n\(error.localizedDescription)")
            }
        }
    }
    
    public func withTransaction(_ name: String = #function, _ block: (NSManagedObjectContext) -> Void) {
        
        logger.info("CoreData.withTransaction begin \(name)")
        
        var timeExpired: Bool = false
        withExtendedBackgroundLifetime(name, onExpire: { [weak self] in
            self?.logger.info("CoreData.withTransaction expired \(name)")
            timeExpired = true
        }) {
            // perform actions
            // save or rollback
            context.performAndWait {
                do {
                    block(context)
                    if timeExpired {
                        context.rollback()
                    } else {
                        try? context.save()
                    }
                } catch {
                    logger.critical("transaction error: \(error)")
                }
            }
            
            logger.info("CoreData.withTransaction completed \(name)")
        }
    }
}
