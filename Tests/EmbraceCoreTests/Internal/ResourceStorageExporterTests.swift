import EmbraceCommonInternal
import EmbraceStorageInternal
import OpenTelemetryApi
//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal

final class ResourceStorageExporterTests: XCTestCase {
    func test_exporter_gets_every_type_of_resource() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let exporter = ResourceStorageExporter(storage: storage)

        storage.addMetadata(
            key: "permanent",
            value: "permanent",
            type: .resource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "session",
            value: "session",
            type: .resource,
            lifespan: .session,
            lifespanId: "sessionId"
        )
        storage.addMetadata(
            key: "process",
            value: "process",
            type: .resource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )
        // A process-scoped resource left behind by an earlier launch. Records like these share keys
        // with the current process's, and whichever the store returned last used to win. They are
        // now left out, so only the current process's value can be exported.
        storage.addMetadata(
            key: "foreign",
            value: "foreign",
            type: .resource,
            lifespan: .process,
            lifespanId: "someOtherProcessId"
        )

        let resource = exporter.getResource()
        XCTAssertEqual(resource.attributes.count, 6)
        XCTAssertNil(resource.attributes["foreign"])

        XCTAssertEqual(resource.attributes["session"], .string("session"))
        XCTAssertEqual(resource.attributes["process"], .string("process"))
        XCTAssertEqual(resource.attributes["permanent"], .string("permanent"))

        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))

        let serviceName = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
            .compactMap { $0 }
            .joined(separator: ":")
        XCTAssertEqual(resource.attributes["service.name"], .string(serviceName))
        XCTAssertEqual(
            resource.attributes["service.version"],
            .string(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String))
    }
}
