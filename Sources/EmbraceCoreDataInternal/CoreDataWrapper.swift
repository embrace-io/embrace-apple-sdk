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
                description.setOption(FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
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

        context.performAndWait {

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
    /// If the background task can't be created, the block will be called without a context.
    public func performOperation(name: String, _ block: (NSManagedObjectContext?) -> Void) {

        if options.enableBackgroundTasks == false {
            context.performAndWait {
                block(context)
            }
        } else {
            context.performAndWait {
                let taskName = options.storageMechanism.name + "_" + name
                guard let task = BackgroundTaskWrapper(name: taskName, logger: logger) else {
                    block(nil)
                    return
                }

                block(context)
                task.finish()
            }
        }
    }

    /// Synchronously saves all changes on the current context to disk
    public func save() {
        performOperation(name: "Save") { [weak self] context in
            guard let self, let context else {
                return
            }

            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                let name = context.name ?? "???"
                self.logger.critical("Error saving CoreData \"\(name)\": \(error.localizedDescription)")
            }
        }
    }

    /// Synchronously fetches the records that satisfy the given request
    public func fetch<T>(withRequest request: NSFetchRequest<T>) -> [T] where T: NSManagedObject {

        var result: [T] = []
        performOperation(name: "Fetch") { [weak self] context in
            guard let self, let context else {
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

        performOperation(name: "FetchAndPerform") { [weak self] context in
            guard let self, let context else {
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

        performOperation(name: "FetchFirstAndPerform") { [weak self] context in
            guard let self, let context else {
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
        performOperation(name: "Count") { [weak self] context in
            guard let self, let context else {
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
        
        performOperation(name: "DeleteRecords") { [weak self] context in
            guard let self, let context else {
                return
            }

            for record in records {
                context.delete(record)
            }

            do {
                try context.save()
            } catch {
                self.logger.critical("Error deleting records!!!:\n\(error.localizedDescription)")
            }
        }
    }

    /// Synchronously deletes requested records that satisfy the given request from the database and saves.
    public func deleteRecords<T>(withRequest request: NSFetchRequest<T>)where T: NSManagedObject {
        
        performOperation(name: "DeleteRecords") { [weak self] context in
            guard let self, let context else {
                return
            }

            do {
                let records = try context.fetch(request)
                for record in records {
                    context.delete(record)
                }

                try context.save()
            } catch {
                self.logger.critical("Error deleting records with request:\n\(error.localizedDescription)")
            }
        }
    }
}
