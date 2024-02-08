//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTel
import OpenTelemetryApi
import EmbraceStorage

final class ResourceStorageExporterTests: XCTestCase {
    func test_exorter_gets_every_type_of_resource() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let exporter = ResourceStorageExporter(storage: storage)

        try storage.addResource(key: "permanent", value: "permanent", resourceType: .permanent)
        try storage.addResource(key: "session", value: "session", resourceType: .session)
        try storage.addResource(key: "process", value: "process", resourceType: .process)

        let resources = exporter.getResources()

        XCTAssertEqual(resources.count, 3)

        XCTAssertTrue(resources.contains(where: {$0.key == "permanent" && $0.value.description == "permanent"}))
        XCTAssertTrue(resources.contains(where: {$0.key == "session" && $0.value.description == "session"}))
        XCTAssertTrue(resources.contains(where: {$0.key == "process" && $0.value.description == "process"}))
    }
}
