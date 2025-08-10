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

    public init(options: CoreDataWrapper.Options, logger: InternalLogger) throws {
        self.options = options
        self.logger = logger
        self.workTracker = WorkTracker(name: self.options.storageMechanism.name, logger: self.logger)
        isTesting = ProcessInfo.processInfo.isTesting

        // create model
        let model = NSManagedObjectModel()
        model.entities = options.entities

        // create container
        let name = options.storageMechanism.name
        container = NSPersistentContainer(name: name, managedObjectModel: model)

        // force db on memory during tests
        if isTesting {
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

                container.persistentStoreDescriptions = [description]
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                logger.critical("Error initializing CoreData \"\(name)\": \(error.localizedDescription)")
            }
        }

        context = container.newBackgroundContext()
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
    private func saveIfNeeded() {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            logger.critical(
                """
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

// The work tracker is meant to track core data work through a ref count.
// Each decrement allows a leeway of N seconds in order to group spurts of
// work. This allows us to ensure that, when required, we can do other work once
// that group of work is done, such as run a background task assertion
// to finish up work on backgrounding.

typealias WorkTrackerID = UInt64

private class WorkTracker {

    let name: String
    let logger: InternalLogger
    var observer: NSObjectProtocol?

    struct BusyData {
        var liveIDs: Set<WorkTrackerID> = Set()
        var currentID: WorkTrackerID = 1
        var onIdle: (() -> Void)?
    }
    private var _busyData = EmbraceMutex(BusyData())

    init(name: String, logger: InternalLogger) {
        self.name = name
        self.logger = logger
        self.observer = nil
        #if canImport(UIKit)
            self.observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                self?.didEnterBackground()
            }
        #endif
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func increment(_ label: String = #function) -> WorkTrackerID {
        return _busyData.withLock {
            let nextId = $0.currentID
            $0.liveIDs.insert(nextId)
            $0.currentID += 1
            return nextId
        }
    }

    public func decrement(
        _ label: String = #function, id: WorkTrackerID, afterDebounce: Bool, debounceInterval: TimeInterval = 2.0
    ) {
        if afterDebounce {
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) { [self] in
                _decrement(label, id: id)
            }
        } else {
            _decrement(label, id: id)
        }
    }

    private func _decrement(_ label: String = #function, id: WorkTrackerID) {
        let value: (() -> Void)? = _busyData.withLock {

            // check and remove form the live set
            guard $0.liveIDs.remove(id) != nil else {
                logger.critical("[BG] \(name) trying to decrement id \(id) that isn't live")
                return nil
            }

            guard $0.liveIDs.isEmpty else {
                return nil
            }

            let block = $0.onIdle
            $0.onIdle = nil
            return block
        }
        if let value {
            value()
        }
    }

    public var busy: Bool {
        _busyData.withLock { $0.liveIDs.isEmpty == false }
    }

    private func onIdle(_ block: (() -> Void)?) {
        let value = _busyData.withLock {
            if $0.liveIDs.isEmpty {
                $0.onIdle = nil
                return block
            }
            $0.onIdle = block
            return nil
        }
        if let value {
            value()
        }
    }

    /// Called when the app is backgrounded on certain platforms that require extra time
    /// for the database to finish up its work.
    private func didEnterBackground() {

        // In essence, we want a task assertion to run on backgrounding to make
        // sure all our core data work has time to finish.
        let task = BackgroundTaskAssertion(name: "embrace.coredata.background.\(name)", logger: logger)
        let id = increment()
        onIdle {
            task?.finish()
        }
        decrement(id: id, afterDebounce: true)
    }
}
