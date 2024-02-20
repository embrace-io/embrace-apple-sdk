//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore
import XCTest
import EmbraceStorage
import EmbraceCommon
import TestSupport

// swiftlint:disable force_cast

final class MetadataHandlerTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        try storage.teardown()
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
        let expectation = XCTestExpectation()
        try handler.addResource(key: "test", value: invalidValue, lifespan: .permanent)
        try handler.addProperty(key: "test", value: invalidValue, lifespan: .permanent)

        // then the values are truncated
        try storage.dbQueue.read { db in
            let records = try MetadataRecord.fetchAll(db)
            for metadata in records {
                XCTAssertEqual(metadata.stringValue!.count, MetadataHandler.maxValueLength)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
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
            try storage.addMetadata(key: "resource\(i)", value: "test", type: .resource, lifespan: .permanent)
        }

        for i in 1...storage.options.customPropertiesLimit {
            try storage.addMetadata(key: "resource\(i)", value: "test", type: .customProperty, lifespan: .permanent)
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
}

// swiftlint:enable force_cast
