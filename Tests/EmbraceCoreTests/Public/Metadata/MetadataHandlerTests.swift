//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore
import XCTest
import EmbraceStorageInternal
import EmbraceCommonInternal
import TestSupport
import CoreData

// swiftlint:disable force_cast

final class MetadataHandlerTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)

        storage.addSession(
            id: sessionController.currentSession!.id!,
            processId: .current,
            state: .foreground,
            traceId: .random(),
            spanId: .random(),
            startTime: Date()
        )
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        sessionController = nil
    }

    func test_key_validation() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        var invalidKey = ""
        for _ in 1...MetadataHandler.maxKeyLength + 1 {
            invalidKey += "a"
        }

        // when adding a resource with invalid key
        let expectation1 = XCTestExpectation()
        XCTAssertThrowsError(try handler.addResource(key: invalidKey, value: "test")) { error in

            // then it should error out as a MetadataError.invalidKey
            switch error as! MetadataError {
            case .invalidKey:
                expectation1.fulfill()
            default:
                XCTAssert(false)
            }
        }

        // when adding a property with invalid key
        let expectation2 = XCTestExpectation()
        XCTAssertThrowsError(try handler.addProperty(key: invalidKey, value: "test")) { error in

            // then it should error out as a MetadataError.invalidKey
            switch error as! MetadataError {
            case .invalidKey:
                expectation2.fulfill()
            default:
                XCTAssert(false)
            }
        }

        wait(for: [expectation1, expectation2], timeout: .defaultTimeout)
    }

    func test_value_validation() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        var invalidValue = ""
        for _ in 1...MetadataHandler.maxValueLength + 10 {
            invalidValue += "a"
        }

        // when adding metadata with invalid values
        try handler.addResource(key: "test", value: invalidValue, lifespan: .permanent)
        try handler.addProperty(key: "test", value: invalidValue, lifespan: .permanent)

        // then the values are truncated
        let metadata: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(metadata.count, 2)
        XCTAssertEqual(metadata[0].value.count, MetadataHandler.maxValueLength)
        XCTAssertEqual(metadata[1].value.count, MetadataHandler.maxValueLength)
    }

    func test_currentSession_validation() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // given no current session
        sessionController.endSession()

        // when adding a resource with session lifespan
        let expectation1 = XCTestExpectation()
        XCTAssertThrowsError(try handler.addResource(key: "test", value: "test", lifespan: .session)) { error in

            // then it should error out as a MetadataError.invalidSession
            switch error as! MetadataError {
            case .invalidSession:
                expectation1.fulfill()
            default:
                XCTAssert(false)
            }
        }

        // when adding a property with session lifespan
        let expectation2 = XCTestExpectation()
        XCTAssertThrowsError(try handler.addProperty(key: "test", value: "test", lifespan: .session)) { error in

            // then it should error out as a MetadataError.invalidSession
            switch error as! MetadataError {
            case .invalidSession:
                expectation2.fulfill()
            default:
                XCTAssert(false)
            }
        }

        wait(for: [expectation1, expectation2], timeout: .defaultTimeout)
    }

    func test_limit_validation() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // given limits reached on metadata
        for i in 1...storage.options.resourcesLimit {
            storage.addMetadata(key: "resource\(i)", value: "test", type: .resource, lifespan: .permanent)
        }

        for i in 1...storage.options.customPropertiesLimit {
            storage.addMetadata(key: "resource\(i)", value: "test", type: .customProperty, lifespan: .permanent)
        }

        // when adding a resource
        let expectation1 = XCTestExpectation()
        XCTAssertThrowsError(try handler.addResource(key: "test", value: "test", lifespan: .session)) { error in

            // then it should error out as a MetadataError.limitReached
            switch error as! MetadataError {
            case .limitReached:
                expectation1.fulfill()
            default:
                XCTAssert(false)
            }
        }

        // when adding a custom property
        let expectation2 = XCTestExpectation()
        XCTAssertThrowsError(try handler.addProperty(key: "test", value: "test", lifespan: .session)) { error in

            // then it should error out as a MetadataError.limitReached
            switch error as! MetadataError {
            case .limitReached:
                expectation2.fulfill()
            default:
                XCTAssert(false)
            }
        }

        wait(for: [expectation1, expectation2], timeout: .defaultTimeout)
    }

    // MARK: Removing Metadata

    func test_remove_removesMetadata_withSessionLifespan() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // when added
        try handler.addProperty(key: "foo", value: "bar", lifespan: .session)

        let firstFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .session)

        let secondFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    func test_remove_doesNot_removeMetadataWithSessionLifespan_whenSessionChanges() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        let firstSessionId = sessionController.currentSession!.id!
        // when added to first session
        try handler.addProperty(key: "foo", value: "bar", lifespan: .session)

        // start new session
        let newSession = sessionController.startSession(state: .foreground)
        let secondSessionId = newSession!.id!
        storage.addSession(
            id: secondSessionId,
            processId: .current,
            state: .foreground,
            traceId: .random(),
            spanId: .random(),
            startTime: Date()
        )

        let fetch1 = storage.fetchCustomPropertiesForSessionId(firstSessionId)
        let result1 = fetch1.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(result1)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .session)

        let fetch2 = storage.fetchCustomPropertiesForSessionId(secondSessionId)
        let result2 = fetch2.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result2)    // not present from second session

        let fetch3 = storage.fetchCustomPropertiesForSessionId(firstSessionId)
        let result3 = fetch3.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(result3) // still present in first session
    }

    func test_remove_removesMetadata_withProcessLifespan() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // when added
        try handler.addProperty(key: "foo", value: "bar", lifespan: .process)

        let firstFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .process)

        let secondFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    func test_remove_doesNot_removeMetadataWithProcessLifespan_whenProcessChanges() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        let otherProcessId = ProcessIdentifier.random
        let otherSessionId = SessionIdentifier.random
        storage.addSession(
            id: otherSessionId,
            processId: otherProcessId,
            state: .foreground,
            traceId: .random(),
            spanId: .random(),
            startTime: Date()
        )

        // when added to process that occurred "before"
        storage.addMetadata(
            key: "foo",
            value: "bar",
            type: .customProperty,
            lifespan: .process,
            lifespanId: otherProcessId.hex
        )

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .process)

        // exists in other session
        let fetch1 = storage.fetchCustomPropertiesForSessionId(otherSessionId)
        let result1 = fetch1.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(result1)

        // does not exist in current session
        let fetch2 = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let result2 = fetch2.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result2)    // not present from second session
    }

    func test_remove_removesMetadata_withPermanentLifespan() throws {
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // when added
        try handler.addProperty(key: "foo", value: "bar", lifespan: .permanent)

        let firstFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .permanent)

        let secondFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id!)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    // MARK: tmp core data
    func test_coreDataClone() throws {
        // given stored metadata
        for i in 1...3 {
            storage.addMetadata(key: "resource\(i)", value: "test", type: .resource, lifespan: .permanent)
            storage.addMetadata(key: "property\(i)", value: "test", type: .customProperty, lifespan: .permanent)
        }

        // when initializing a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // the data is cloned into a temporal core data stack
        XCTAssertNotNil(handler.coreData)

        let request = NSFetchRequest<MetadataRecordTmp>(entityName: MetadataRecordTmp.entityName)
        let result = handler.coreData!.fetch(withRequest: request)

        XCTAssertEqual(result.count, 6)
        XCTAssertNotNil(result.first(where: { $0.key == "resource1" }))
        XCTAssertNotNil(result.first(where: { $0.key == "resource2" }))
        XCTAssertNotNil(result.first(where: { $0.key == "resource3" }))
        XCTAssertNotNil(result.first(where: { $0.key == "property1" }))
        XCTAssertNotNil(result.first(where: { $0.key == "property2" }))
        XCTAssertNotNil(result.first(where: { $0.key == "property3" }))
    }
}

// swiftlint:enable force_cast
