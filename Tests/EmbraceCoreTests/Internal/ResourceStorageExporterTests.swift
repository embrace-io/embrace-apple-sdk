//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
import OpenTelemetryApi
import EmbraceStorageInternal

final class ResourceStorageExporterTests: XCTestCase {
    func test_exorter_gets_every_type_of_resource() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let exporter = ResourceStorageExporter(storage: storage)

        try storage.addMetadata(
            key: "permanent",
            value: "permanent",
            type: .resource,
            lifespan: .permanent
        )
        try storage.addMetadata(
            key: "session",
            value: "session",
            type: .resource,
            lifespan: .session,
            lifespanId: "sessionId"
        )
        try storage.addMetadata(
            key: "process",
            value: "process",
            type: .resource,
            lifespan: .process,
            lifespanId: "processId"
        )

        let resources = exporter.getResources()

        XCTAssertEqual(resources.count, 3)

        XCTAssertTrue(resources.contains(where: {$0.key == "permanent" && $0.value.description == "permanent"}))
        XCTAssertTrue(resources.contains(where: {$0.key == "session" && $0.value.description == "session"}))
        XCTAssertTrue(resources.contains(where: {$0.key == "process" && $0.value.description == "process"}))
    }
}
