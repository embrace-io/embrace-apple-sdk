//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if canImport(UIKit)
    import UIKit
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
#endif

public class CoreDataWrapper {
    public let options: CoreDataWrapper.Options

    var container: NSPersistentContainer!
    public private(set) var context: NSManagedObjectContext!
    let logger: InternalLogger

    private let workTracker: WorkTracker

    private var name: String {
        options.storageMechanism.name
    }

    private let isTesting: Bool
    private var isLoadingStore = false
    static let modelCache: EmbraceMutex<[String: NSManagedObjectModel]> = EmbraceMutex([:])

    public init(
        options: CoreDataWrapper.Options,
        logger: InternalLogger,
        isTesting: Bool = ProcessInfo.processInfo.isTesting
    ) throws {
        self.options = options
        self.logger = logger
        self.isTesting = isTesting
        self.workTracker = WorkTracker(name: self.options.storageMechanism.name, logger: self.logger)

        // create model
        let entitiesCacheKey = options.entities
            .map { $0.managedObjectClassName }
            .sorted()
            .joined(separator: "-")
        let model = Self.modelCache.withLock {
            if let model = $0[entitiesCacheKey] {
                return model
            }
            let model = NSManagedObjectModel()
            model.entities = options.entities
            $0[entitiesCacheKey] = model
            return model
        }

        // create container
        let name = options.storageMechanism.name
        container = NSPersistentContainer(name: name, managedObjectModel: model)

        // force db on memory during tests
        if self.isTesting {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]

        } else {
            switch options.storageMechanism {
            case .inMemory:
                let description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
                container.persistentStoreDescriptions = [description]

            case let .onDisk(_, baseURL, journalMode):
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
                let description = NSPersistentStoreDescription()
                #if !os(macOS)
                    description.setOption(
                        FileProtectionType.none as NSObject, forKey: NSPersistentStoreFileProtectionKey)
                #endif
                description.type = NSSQLiteStoreType
                description.url = options.storageMechanism.fileURL
                description.setValue(journalMode.rawValue as NSString, forPragmaNamed: "journal_mode")
                description.shouldAddStoreAsynchronously = true
                container.persistentStoreDescriptions = [description]

            }
        }

        // We load the persistent store asynchronously to avoid a main-thread deadlock during early app
        // launch. CoreData internally may try to dispatch back to the main thread during store loading
        // recovery; if the main thread is blocked waiting for this call, a deadlock occurs. With
        // shouldAddStoreAsynchronously = true, the context automatically queues operations until the
        // store is ready, so callers are unaffected. Load errors are logged in the completion callback.
        loadPersistentStoreIfNeeded(logIfEmpty: false)

        context = container.newBackgroundContext()
    }

    private func loadPersistentStoreIfNeeded(logIfEmpty: Bool = true) {
        guard container.persistentStoreCoordinator.persistentStores.isEmpty,
              !isLoadingStore else { return }

        if logIfEmpty { logger.critical("Persistent store is empty for \"\(name)\"") }

        isLoadingStore = true
        container.loadPersistentStores { [weak self] _, error in
            self?.isLoadingStore = false
            if let error = error {
                self?.logger.critical(
                    "Error loading persistent stores for \"\(self?.name ?? "?")\": \(error.localizedDescription)"
                )
            }
        }
    }

    /// Synchronously performs the given block on the current context
    /// behind a background task assertion.
    /// And automatically save if requested.
    /// Note we do not cancel currently any tasks on assertion expiry,
    /// Note don't we care if a task assertion is actually given to us.
    public func performOperation<Result>(
        _ name: String = #function, save: Bool = false, allowMainQueue: Bool = false,
        _ block: (NSManagedObjectContext) -> Result
    ) -> Result {

        if !allowMainQueue && Thread.isMainThread {
            logger.critical("Warning: performBlockAndWait on main thread can easily deadlock! Proceeding with caution.")
        }

        let id = workTracker.increment(name)

        var result: Result!
        context.performAndWait {
            result = block(context)
            if save {
                saveIfNeeded()
            }
            workTracker.decrement(name, id: id, afterDebounce: true)
        }

        return result
    }

    /// Asynchronously performs the given block on the current context
    /// behind a background task assertion.
    /// And automatically save if requested.
    public func performAsyncOperation(
        _ name: String = #function, save: Bool = false, _ block: @escaping (NSManagedObjectContext) -> Void
    ) {
        let id = workTracker.increment(name)

        let cntxt: NSManagedObjectContext = context
        cntxt.perform { [self, cntxt] in
            block(cntxt)
            if save {
                saveIfNeeded()
            }
            workTracker.decrement(name, id: id, afterDebounce: true)
        }
    }

    /// Requests all changes to be saved to disk as soon as possible
    public func save(allowMainQueue: Bool = false) {
        performOperation(save: true, allowMainQueue: allowMainQueue) { _ in }
    }

    /// Requests all changes to be saved to disk async
    public func saveAsync() {
        performAsyncOperation(save: true) { _ in }
    }
}

// MARK: - Fetch

extension CoreDataWrapper {
    /// Synchronously fetches the records that satisfy the given request
    public func fetch<T>(withRequest request: NSFetchRequest<T>) -> [T] where T: NSManagedObject {
        performOperation {
            do {
                return try $0.fetch(request)
            } catch {
                logger.critical("Error fetching!!!:\n\(error.localizedDescription)")
            }
            return []
        }
    }

    /// Synchronously fetches the records that satisfy the given request and calls the block with them.
    public func fetchAndPerform<T>(withRequest request: NSFetchRequest<T>, block: ([T]) -> Void)
    where T: NSManagedObject {
        performOperation {
            do {
                let result = try $0.fetch(request)
                block(result)
            } catch {
                logger.critical("Error fetching with perform!!!:\n\(error.localizedDescription)")
            }
        }
    }

    /// Synchronously fetches the first record that satisfy the given request and calls the block with it.
    public func fetchFirstAndPerform<T>(withRequest request: NSFetchRequest<T>, block: (T?) -> Void)
    where T: NSManagedObject {
        performOperation {
            do {
                let result = try $0.fetch(request)
                block(result.first)
            } catch {
                logger.critical("Error fetching first with perform!!!:\n\(error.localizedDescription)")
            }
        }
    }

    /// Synchronously fetches the count of records that satisfy the given request.
    public func count<T>(withRequest request: NSFetchRequest<T>) -> Int where T: NSManagedObject {
        performOperation {
            do {
                return try $0.count(for: request)
            } catch {
                logger.critical("Error fetching count!!!:\n\(error.localizedDescription)")
            }
            return 0
        }
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
    public func deleteRecords<T>(withRequest request: NSFetchRequest<T>) where T: NSManagedObject {
        performOperation(save: true) {
            do {
                let records = try $0.fetch(request)
                for record in records {
                    $0.delete(record)
                }
            } catch {
                logger.critical("Error deleting records with request:\n\(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Internal saves

extension CoreDataWrapper {

    @discardableResult
    package func saveIfNeeded() -> Bool {

        guard context.hasChanges else {
            return true
        }

        // For some reason, persistent stores seem to go away sometimes,
        // let's try and load them if needed.
        loadPersistentStoreIfNeeded()

        // Call into ObjC to capture any ObjC exceptions thrown.
        if let error = EmbraceSaveManagedContext(context) {

            let nsError = error as NSError

            // Log the error so we have a trace
            logger.critical(
                """
                CoreData save failed '\(context.name ?? "???")',
                error: \(error.localizedDescription),
                """,
                attributes: nsError.userInfo.compactMapValues { "\($0)" }
            )
            return false
        }
        return true

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
