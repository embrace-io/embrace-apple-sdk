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

    func test_addRequiredResource() throws {
        // given a resource capture service
        let service = ResourceCaptureService()
        let handler = try EmbraceStorage.createInMemoryDb()
        service.handler = handler

        // when adding a resource
        let map = [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3"
        ]
        service.addRequiredResources(map)

        // then the resource is added to the storage
        let metadata: [MetadataRecord] = handler.fetchAll()
        XCTAssertEqual(metadata.count, 3)
        XCTAssertEqual(metadata[0].typeRaw, "requiredResource")
        XCTAssertEqual(metadata[0].lifespanRaw, "process")
        XCTAssertEqual(metadata[0].lifespanId, ProcessIdentifier.current.hex)
    }
}
