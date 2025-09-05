//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceStorageInternal

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
        wait(delay: .shortTimeout)

        // then the resource is added to the storage
        let metadata: [MetadataRecord] = handler.fetchAll()
        XCTAssertEqual(metadata.count, 3)
        XCTAssertEqual(metadata[0].typeRaw, "requiredResource")
        XCTAssertEqual(metadata[0].lifespanRaw, "process")
        XCTAssertEqual(metadata[0].lifespanId, ProcessIdentifier.current.stringValue)
    }

    func test_addCriticalResource() throws {
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
        service.addCriticalResources(map)

        // then the resource is added to the storage
        let metadata: [MetadataRecord] = handler.fetchAll()
        XCTAssertEqual(metadata.count, 3)
        XCTAssertEqual(metadata[0].typeRaw, "requiredResource")
        XCTAssertEqual(metadata[0].lifespanRaw, "process")
        XCTAssertEqual(metadata[0].lifespanId, ProcessIdentifier.current.stringValue)
    }
}
