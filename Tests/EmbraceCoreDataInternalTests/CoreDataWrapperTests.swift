//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import Foundation
import SQLite3
import TestSupport
import XCTest

@testable import EmbraceCoreDataInternal

class CoreDataWrapperTests: XCTestCase {

    var wrapper: CoreDataWrapper!

    override func setUpWithError() throws {
        let storageMechanism: StorageMechanism = .inMemory(name: testName)
        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        try wrapper = CoreDataWrapper(options: options, logger: MockLogger())
    }

    func skip_test_destroy() throws {
        // given a wrapper with data on disk
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let storageMechanism: StorageMechanism = .onDisk(name: testName, baseURL: url, journalMode: .delete)
        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        try wrapper = CoreDataWrapper(options: options, logger: MockLogger())

        _ = MockRecord.create(context: wrapper.context, id: "test")
        wrapper.save()

        XCTAssert(FileManager.default.fileExists(atPath: storageMechanism.fileURL!.path))

        // when destroying the stack
        wrapper.destroy()

        // then the db file is removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageMechanism.fileURL!.path))
    }

    func test_fetch() throws {
        // given a wrapper with data
        _ = MockRecord.create(context: wrapper.context, id: "test")
        wrapper.save()

        // when fetching data
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        request.predicate = NSPredicate(format: "id == %@", "test")

        let result = wrapper.fetch(withRequest: request)

        // then the data is correct
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.id, "test")
    }

    func test_fetchAndPerform() throws {
        // given a wrapper with data
        _ = MockRecord.create(context: wrapper.context, id: "test")
        wrapper.save()

        // when fetching data and performing a block
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        request.predicate = NSPredicate(format: "id == %@", "test")

        wrapper.fetchAndPerform(withRequest: request) { records in

            // then the data is correct
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].id, "test")
        }
    }

    func test_fetchFirstAndPerform() throws {
        // given a wrapper with data
        _ = MockRecord.create(context: wrapper.context, id: "a")
        _ = MockRecord.create(context: wrapper.context, id: "z")
        wrapper.save()

        // when fetching data and performing a block
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]

        wrapper.fetchFirstAndPerform(withRequest: request) { record in

            // then the data is correct
            XCTAssertEqual(record!.id, "a")
        }
    }

    func test_count() throws {
        // given a wrapper with data
        _ = MockRecord.create(context: wrapper.context, id: "test1")
        _ = MockRecord.create(context: wrapper.context, id: "test2")
        _ = MockRecord.create(context: wrapper.context, id: "test3")
        wrapper.save()

        // when fetching count
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        let result = wrapper.count(withRequest: request)

        // then the data is correct
        XCTAssertEqual(result, 3)
    }

    func test_deleteRecord() throws {
        // given a wrapper with data
        let record = MockRecord.create(context: wrapper.context, id: "test")
        wrapper.save()

        // when deleting the record
        wrapper.deleteRecord(record)

        // then the record is deleted
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        let result = wrapper.fetch(withRequest: request)

        XCTAssertEqual(result.count, 0)
    }

    func test_deleteRecords() throws {
        // given a wrapper with data
        let record1 = MockRecord.create(context: wrapper.context, id: "test1")
        let record2 = MockRecord.create(context: wrapper.context, id: "test2")
        wrapper.save()

        // when deleting the record
        wrapper.deleteRecords([record1, record2])

        // then the record is deleted
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        let result = wrapper.fetch(withRequest: request)

        XCTAssertEqual(result.count, 0)
    }

    func test_deleteRecords_withRequest() throws {
        // given a wrapper with data
        _ = MockRecord.create(context: wrapper.context, id: "test1")
        _ = MockRecord.create(context: wrapper.context, id: "test2")
        wrapper.save()

        // when deleting the record
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        wrapper.deleteRecords(withRequest: request)

        // then the record is deleted
        let result = wrapper.fetch(withRequest: request)
        XCTAssertEqual(result.count, 0)
    }

    func test_performOperation_returnsNil() throws {
        let expectedReturnValue: Int? = nil
        let val = wrapper.performOperation { _ in
            expectedReturnValue
        }
        XCTAssertEqual(val, expectedReturnValue)
    }

    func test_performOperation_returnsOptionalValue() throws {
        let expectedReturnValue: Int? = 12
        let val = wrapper.performOperation { _ in
            expectedReturnValue
        }
        XCTAssertEqual(val, expectedReturnValue)
    }

    func test_performOperation_returnsValue() throws {
        let expectedReturnValue: Int = 12
        let val = wrapper.performOperation { _ in
            expectedReturnValue
        }
        XCTAssertEqual(val, expectedReturnValue)
    }

    /// This test is just here to show one that would not compile
    /// due to a missing return value.
    /// ERROR: `Missing return in closure expected to return 'Int'`
    /**
    func test_performOperation_returnsValueWontCompile() throws {
        let expectedReturnValue: Int = 12
        let val = wrapper.performOperation { _ in
            guard true else {
                return expectedReturnValue
            }
            //return expectedReturnValue
        }
        XCTAssertEqual(val, expectedReturnValue)
    }
     */

    func test_performOperation_noValue() throws {
        // this test just ensure things compile.
        wrapper.performOperation { _ in }
    }

    func test_init_doesNotWaitForTheStoreToLoad() throws {
        // given an existing store on disk
        let storageMechanism = try makeOnDiskStorageMechanism()
        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false).save()

        // and another connection holding an exclusive lock on it, so loading it stalls
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(storageMechanism.fileURL!.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "BEGIN EXCLUSIVE", nil, nil, nil), SQLITE_OK)

        // (released after a few seconds anyway, so a regression that waits for the load fails instead of hanging)
        let releaseLock = lockReleaser(db)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { releaseLock() }

        // when creating the wrapper
        let start = Date()
        wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        // then it returns while the load is stalled
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)

        // and operations queued meanwhile run against the store once it's loaded
        wrapper.performAsyncOperation(save: true) { context in
            _ = MockRecord.create(context: context, id: "test")
        }
        releaseLock()

        let result = wrapper.fetch(withRequest: NSFetchRequest<MockRecord>(entityName: MockRecord.entityName))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.objectID.isTemporaryID, false)
    }

    func test_init_operationsWorkRightAfterInit() throws {
        // given a wrapper with a store on disk
        let options = CoreDataWrapper.Options(
            storageMechanism: try makeOnDiskStorageMechanism(),
            enableBackgroundTasks: false,
            entities: [MockRecord.entityDescription]
        )
        wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        // when writing and reading right after init
        wrapper.performAsyncOperation(save: true) { context in
            _ = MockRecord.create(context: context, id: "test")
        }
        let result = wrapper.fetch(withRequest: NSFetchRequest<MockRecord>(entityName: MockRecord.entityName))

        // then the operations ran against the loaded store
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.objectID.isTemporaryID, false)
    }

    func test_init_doesNotThrow_whenTheStoreFailsToLoad() throws {
        // given a storage path that can't be opened as a store
        let storageMechanism = try makeOnDiskStorageMechanism()
        try FileManager.default.createDirectory(at: storageMechanism.fileURL!, withIntermediateDirectories: true)

        // when creating the wrapper
        let logger = MockLogger()
        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        wrapper = try CoreDataWrapper(options: options, logger: logger, isTesting: false)

        // then operations don't crash and the failure is logged
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        XCTAssertEqual(wrapper.fetch(withRequest: request).count, 0)
        XCTAssertEqual(wrapper.count(withRequest: request), 0)
        XCTAssertTrue(
            logger.loggedMessages.contains {
                $0.level == .critical && $0.message.contains("Error loading persistent stores")
            })
        XCTAssertFalse(wrapper.isStoreLoaded)
    }

    func test_isStoreLoaded() throws {
        // given a wrapper with a store on disk
        let options = CoreDataWrapper.Options(
            storageMechanism: try makeOnDiskStorageMechanism(),
            enableBackgroundTasks: false,
            entities: [MockRecord.entityDescription]
        )
        wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        // then the store is reported as loaded
        XCTAssertTrue(wrapper.isStoreLoaded)
    }

    func test_onInitialLoad_reportsLoaded() throws {
        // given a wrapper with a store on disk
        let options = CoreDataWrapper.Options(
            storageMechanism: try makeOnDiskStorageMechanism(),
            enableBackgroundTasks: false,
            entities: [MockRecord.entityDescription]
        )
        wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        // when waiting for the initial load
        let reported = expectation(description: "load reported")
        wrapper.onInitialLoad { error in
            // then it reports the store as loaded
            XCTAssertNil(error)
            reported.fulfill()
        }
        wait(for: [reported], timeout: 5)
    }

    func test_onInitialLoad_reportsFailure() throws {
        // given a wrapper whose store fails to load
        let storageMechanism = try makeOnDiskStorageMechanism()
        try FileManager.default.createDirectory(at: storageMechanism.fileURL!, withIntermediateDirectories: true)
        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)

        // when waiting for the initial load
        let reported = expectation(description: "load reported")
        wrapper.onInitialLoad { error in
            // then it reports the failure
            XCTAssertNotNil(error)
            reported.fulfill()
        }
        wait(for: [reported], timeout: 5)
    }

    func test_save_whenTheStoreFailedToLoad_failsWithoutTrying() throws {
        // given a wrapper whose store failed to load
        let storageMechanism = try makeOnDiskStorageMechanism()
        try FileManager.default.createDirectory(at: storageMechanism.fileURL!, withIntermediateDirectories: true)

        let logger = MockLogger()
        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        wrapper = try CoreDataWrapper(options: options, logger: logger, isTesting: false)

        // when inserting and saving
        let saved = wrapper.performOperation { context in
            _ = MockRecord.create(context: context, id: "test")
            return self.wrapper.saveIfNeeded()
        }

        // then the save fails without attempting it (which would raise and log a save failure)
        XCTAssertFalse(saved)
        XCTAssertFalse(logger.loggedMessages.contains { $0.message.contains("CoreData save failed") })

        // and the pending record is still visible to fetches
        let request = NSFetchRequest<MockRecord>(entityName: MockRecord.entityName)
        XCTAssertEqual(wrapper.fetch(withRequest: request).count, 1)
    }

    func test_failedLoad_isNotRetried_whenTheStoreBecomesAvailable() throws {
        // given a wrapper whose store failed to load
        let storageMechanism = try makeOnDiskStorageMechanism()
        try FileManager.default.createDirectory(at: storageMechanism.fileURL!, withIntermediateDirectories: true)

        let options = CoreDataWrapper.Options(
            storageMechanism: storageMechanism, enableBackgroundTasks: false, entities: [MockRecord.entityDescription])
        wrapper = try CoreDataWrapper(options: options, logger: MockLogger(), isTesting: false)
        XCTAssertFalse(wrapper.isStoreLoaded)

        // when the store becomes loadable and a record is saved
        try FileManager.default.removeItem(at: storageMechanism.fileURL!)
        wrapper.performAsyncOperation(save: true) { context in
            _ = MockRecord.create(context: context, id: "test")
        }

        // then the store is not attached late (records created meanwhile would duplicate stored ones)
        XCTAssertFalse(wrapper.isStoreLoaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageMechanism.fileURL!.path))
    }

    /// Releases the exclusive lock held by `db` once, from whichever caller gets there first.
    private func lockReleaser(_ db: OpaquePointer?) -> () -> Void {
        let lock = NSLock()
        var released = false
        return {
            lock.lock()
            defer { lock.unlock() }
            guard !released else { return }
            released = true
            XCTAssertEqual(sqlite3_exec(db, "COMMIT", nil, nil, nil), SQLITE_OK)
        }
    }

    private func makeOnDiskStorageMechanism() throws -> StorageMechanism {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: baseURL) }
        return .onDisk(name: "CoreDataWrapperTests", baseURL: baseURL, journalMode: .delete)
    }
}

private class MockRecord: NSManagedObject {
    @NSManaged var id: String

    class func create(context: NSManagedObjectContext, id: String) -> MockRecord {
        // inserts must run on the context's queue, where the wrapper loads the store
        var record: MockRecord!
        context.performAndWait {
            record = MockRecord(context: context)
            record.id = id
        }
        return record
    }

    static let entityName = "MockRecord"

    static var entityDescription: NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(MockRecord.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType
        idAttribute.isOptional = false

        entity.properties = [idAttribute]
        return entity
    }
}
