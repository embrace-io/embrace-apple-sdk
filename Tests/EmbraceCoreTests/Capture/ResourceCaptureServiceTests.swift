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
        let metadata: [MetadataRecord] = handler.fetchAll()
        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata[0].key, "test")
        XCTAssertEqual(metadata[0].value, "value")
        XCTAssertEqual(metadata[0].type, .requiredResource)
        XCTAssertEqual(metadata[0].lifespan, .process)
        XCTAssertEqual(metadata[0].lifespanId, ProcessIdentifier.current.hex)
    }
}
