//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommonInternal
@testable import EmbraceCore
@testable import EmbraceStorageInternal
import OpenTelemetryApi
import TestSupport

class ResourceCaptureServiceTests: XCTestCase {

    func test_addResource() throws {
        // given a resource capture service
        let service = ResourceCaptureService()
        let handler = try EmbraceStorage.createInMemoryDb()
        service.handler = handler

        // when adding a resource
        service.addResource(key: "test", value: .string("value"))

        // then the resource is added to the storage
        let expectation = XCTestExpectation()
        try handler.dbQueue.read { db in
            XCTAssertEqual(try MetadataRecord.fetchCount(db), 1)

            let record = try MetadataRecord.fetchOne(db)
            XCTAssertEqual(record!.key, "test")
            XCTAssertEqual(record!.value, .string("value"))
            XCTAssertEqual(record!.type, .requiredResource)
            XCTAssertEqual(record!.lifespan, .process)
            XCTAssertEqual(record!.lifespanId, ProcessIdentifier.current.hex)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
