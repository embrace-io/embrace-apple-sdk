//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import UIKit

public class CoreDataWrapper {

    public let options: CoreDataWrapper.Options

    var container: NSPersistentContainer!
    public private(set) var context: NSManagedObjectContext!
    let logger: InternalLogger

    // Saving is expensive, so we have a debouncer to only save when idle
    private let debouncer: CoreDataDebouncer = CoreDataDebouncer()
    private var backgroundObserver: NSObjectProtocol? = nil
    
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
        
        if isTesting {
            return
        }
        
        // Don't do this in testing as everything is too set up for sync saves
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else {
                return
            }
            
            guard let task = BackgroundTaskWrapper(name: "BackgroundSave") else {
                return
            }
            
            // Add another block to ensure we have a few seconds of time
            debouncer.perform {}
            
            // now save whenever we end up debouncing
            debouncer.performOnNextBounce { [weak self] in
                self?.saveIfNeededFromDebouncer()
                task.finish()
            }
        }
    }
    
    deinit {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        debouncer.cancel()
    }
    
    /// Synchronously performs the given block on the current context.
    /// And automatically save if requested.
    public func performOperation(_ name: String = #function, save: Bool = false, _ block: (NSManagedObjectContext) -> Void) {

        context.performAndWait {
            block(context)
            if save {
                if isTesting {
                    saveIfNeededFromWithinPerform()
                } else {
                    debouncer.perform { [weak self] in
                        self?.saveIfNeededFromDebouncer()
                    }
                }
            }
        }
    }
    
    /// Requests all changes to be saved to disk as soon as possible
    public func save() {
        performOperation(save: true) { _ in }
    }
}

// MARK: - Fetch

extension CoreDataWrapper {
    
    /// Synchronously fetches the records that satisfy the given request
    public func fetch<T>(withRequest request: NSFetchRequest<T>) -> [T] where T: NSManagedObject {
        
        var result: [T] = []
        performOperation {
            do {
                result = try $0.fetch(request)
            } catch {
                self.logger.critical("Error fetching!!!:\n\(error.localizedDescription)")
            }
        }
        return result
    }
    
    /// Synchronously fetches the records that satisfy the given request and calls the block with them.
    public func fetchAndPerform<T>(withRequest request: NSFetchRequest<T>, block: (([T]) -> Void)) where T: NSManagedObject {
        
        performOperation {
            do {
                let result = try $0.fetch(request)
                block(result)
            } catch {
                self.logger.critical("Error fetching with perform!!!:\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Synchronously fetches the first record that satisfy the given request and calls the block with it.
    public func fetchFirstAndPerform<T>(withRequest request: NSFetchRequest<T>, block: ((T?) -> Void)) where T: NSManagedObject {
        
        performOperation {
            do {
                let result = try $0.fetch(request)
                block(result.first)
            } catch {
                self.logger.critical("Error fetching first with perform!!!:\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Synchronously fetches the count of records that satisfy the given request.
    public func count<T>(withRequest request: NSFetchRequest<T>) -> Int where T: NSManagedObject {
        
        var result: Int = 0
        performOperation {
            do {
                result = try $0.count(for: request)
            } catch {
                self.logger.critical("Error fetching count!!!:\n\(error.localizedDescription)")
            }
        }
        return result
    }
}

// MARK: - Deletion

extension CoreDataWrapper {
    
    /// Synchronously deletes record from the database and saves.
    public func deleteRecord<T>(_ record: T) where T: NSManagedObject {
        performOperation(save: true) {
            $0.delete(record)
        }
    }
    
    /// Synchronously deletes requested records from the database and saves.
    public func deleteRecords<T>(_ records: [T]) where T: NSManagedObject {
        performOperation(save: true) {
            for record in records {
                $0.delete(record)
            }
        }
    }
    
    /// Synchronously deletes requested records that satisfy the given request from the database and saves.
    public func deleteRecords<T>(withRequest request: NSFetchRequest<T>)where T: NSManagedObject {
        
        performOperation(save: true) {
            do {
                let records = try $0.fetch(request)
                for record in records {
                    $0.delete(record)
                }
            } catch {
                self.logger.critical("Error deleting records with request:\n\(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Transactions

extension CoreDataWrapper {
    
    /// Trasaction based work.
    /// Runs your CoreData updates behind a background task assertion,
    /// Performs a rollback if the task assertion expires, saves otherwise.
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
                        try context.save()
                    }
                } catch {
                    logger.critical("transaction error: \(error)")
                }
            }
            
            logger.info("CoreData.withTransaction completed \(name)")
        }
    }
}

// MARK: - Internal saves

extension CoreDataWrapper {
    
    private func saveIfNeededFromDebouncer() {
        context.performAndWait {
            saveIfNeededFromWithinPerform()
        }
    }
    
    private func saveIfNeededFromWithinPerform() {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            self.logger.critical("""
                    CoreData save failed '\(context.name ?? "???")', 
                    error: \(error.localizedDescription), 
                    """
            )
        }
    }
}

// MARK: - Testing

extension CoreDataWrapper {
    
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
}

// MARK: - Debounce

// Simple debouncer used for CoreData saves
private class CoreDataDebouncer {
    
    private var workItem: DispatchWorkItem? = nil
    private let queue: DispatchQueue
    private var nextBounceAction: EmbraceMutex<(() -> Void)?> = EmbraceMutex(nil)

    public init() {
        self.queue = DispatchQueue(
            label: "io.embrace.coredata.debouncer.queue",
            qos: .utility,
            autoreleaseFrequency: .workItem,
            target: DispatchQueue.global(qos: .utility)
        )
        
    }
    
    public func cancel() {
        workItem?.cancel()
        workItem = nil
    }
    
    /// Add _block_ to the queue and debounce by _deadline_
    public func perform(_ name: String = #function, deadline: TimeInterval = 3.0, _ block: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem { [weak self] in
            // Run the submitted block
            block()
            
            // If there's a block to be run on bounce, then take its value
            // and run it.
            if let act = self?.nextBounceAction.safelyTake() ?? nil {
                act()
            }
        }
        if let workItem {
            queue.asyncAfter(deadline: .now() + deadline, execute: workItem)
        }
    }
    
    /// Setup _block_ to run after the next debounced block.
    public func performOnNextBounce( _ block: @escaping () -> Void) {
        nextBounceAction.withLock { $0 = block }
    }
    
    deinit {
        workItem?.cancel()
        workItem = nil
        _ = nextBounceAction.safelyTake()
    }
}
