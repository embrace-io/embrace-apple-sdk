import EmbraceStorageInternal
import TestSupport
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
            lifespanId: "processId"
        )

        let resource = exporter.getResource()
        XCTAssertEqual(resource.attributes.count, 6)

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
	
	func test_userinfos_appear_in_resource() throws {
		// Given
		let storage = try EmbraceStorage.createInMemoryDb()
		let exporter = ResourceStorageExporter(storage: storage)
		let sessionController = MockSessionController()
		sessionController.storage = storage
		sessionController.startSession(state: .foreground)
		let handler = MetadataHandler(
			storage: storage,
			sessionController: sessionController,
			syncronizationQueue: MockQueue()
		)
		
		// When the user sets these
		handler.userName = "example"
		handler.userEmail = "example@example.com"
		handler.userIdentifier = "my-example-identifier"
		
		// They should appear in the output		
		let resource = exporter.getResource()
		XCTAssertEqual(resource.attributes.count, 6)
		
		XCTAssertEqual(resource.attributes[UserResourceKey.name.rawValue], .string("example"))
		XCTAssertEqual(resource.attributes[UserResourceKey.email.rawValue], .string("example@example.com"))
		XCTAssertEqual(resource.attributes[UserResourceKey.identifier.rawValue], .string("my-example-identifier"))
	}
}
