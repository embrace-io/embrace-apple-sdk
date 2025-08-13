//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import Foundation
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

        wrapper.fetchAndPerform(withRequest: request) { records, _ in

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

        wrapper.fetchFirstAndPerform(withRequest: request) { record, _ in

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
}

class MockRecord: NSManagedObject {
    @NSManaged var id: String

    class func create(context: NSManagedObjectContext, id: String) -> MockRecord {
        let record = MockRecord(context: context)
        record.id = id
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

        entity.properties = [idAttribute]
        return entity
    }
}
