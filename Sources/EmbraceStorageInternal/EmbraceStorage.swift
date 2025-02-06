//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceCoreDataInternal
import CoreData

public typealias Storage = EmbraceStorageMetadataFetcher & LogRepository

/// Class in charge of storing all the data captured by the Embrace SDK.
/// It provides an abstraction layer over a CoreData database.
public class EmbraceStorage: Storage {
    public private(set) var options: Options
    public private(set) var logger: InternalLogger
    public private(set) var coreData: CoreDataWrapper

    /// Returns an `EmbraceStorage` instance for the given `EmbraceStorage.Options`
    /// - Parameters:
    ///   - options: `EmbraceStorage.Options` instance
    ///   - logger : `EmbraceConsoleLogger` instance
    public init(options: Options, logger: InternalLogger) throws {
        self.options = options
        self.logger = logger

        // remove old GRDB sqlite file
        if let url = options.storageMechanism.baseUrl?.appendingPathComponent("db.sqlite") {
            try? FileManager.default.removeItem(at: url)
        }

        // create core data stack
        var entities: [NSEntityDescription] = [
            SessionRecord.entityDescription,
            SpanRecord.entityDescription,
            MetadataRecord.entityDescription,
        ]
        entities.append(contentsOf: LogRecord.entityDescriptions)

        let coreDataOptions = CoreDataWrapper.Options(
            storageMechanism: options.storageMechanism,
            entities: entities
        )
        self.coreData = try CoreDataWrapper(options: coreDataOptions, logger: logger)
    }

    /// Saves all changes to disk
    public func save() {
        coreData.save()
    }
}

// MARK: - Sync operations
extension EmbraceStorage {
    /// Deletes a record from the storage synchronously.
    /// - Parameter record: `NSManagedObject` to delete
    public func delete<T: EmbraceStorageRecord>(_ record: T) {
        coreData.deleteRecord(record)
    }

    /// Deletes records from the storage synchronously.
    /// - Parameter record: `NSManagedObject` to delete
    public func delete<T: EmbraceStorageRecord>(_ records: [T]) {
        coreData.deleteRecords(records)
    }

    /// Fetches all the records of the given type in the storage synchronously.
    /// - Returns: Array containing all the records of the given type
    public func fetchAll<T: EmbraceStorageRecord>() -> [T] {
        let request = NSFetchRequest<T>(entityName: T.entityName)
        return coreData.fetch(withRequest: request)
    }
}
