//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class MetadataHandlerTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
        sessionController = MockSessionController()
        sessionController.storage = storage
        sessionController.startSession(state: .foreground)
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
        sessionController = nil
    }

    // MARK: Removing Metadata

    func test_remove_removesMetadata_withSessionLifespan() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // when added
        try handler.addProperty(key: "foo", value: "bar", lifespan: .session)

        let firstFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .session)

        let secondFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    func test_remove_doesNot_removeMetadataWithSessionLifespan_whenSessionChanges() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        let firstSessionId = sessionController.currentSession!.id
        // when added to first session
        try handler.addProperty(key: "foo", value: "bar", lifespan: .session)

        // start new session
        let newSession = sessionController.startSession(state: .foreground)
        let secondSessionId = newSession!.id
        storage.addSession(
            id: secondSessionId,
            processId: ProcessIdentifier.current,
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
        XCTAssertNil(result2)  // not present from second session

        let fetch3 = storage.fetchCustomPropertiesForSessionId(firstSessionId)
        let result3 = fetch3.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(result3)  // still present in first session
    }

    func test_remove_removesMetadata_withProcessLifespan() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // when added
        try handler.addProperty(key: "foo", value: "bar", lifespan: .process)

        let firstFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .process)

        let secondFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    func test_remove_doesNot_removeMetadataWithProcessLifespan_whenProcessChanges() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        let otherProcessId = EmbraceIdentifier.random
        let otherSessionId = EmbraceIdentifier.random
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
            lifespanId: otherProcessId.stringValue
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
        let fetch2 = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let result2 = fetch2.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result2)  // not present from second session
    }

    func test_remove_removesMetadata_withPermanentLifespan() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // when added
        try handler.addProperty(key: "foo", value: "bar", lifespan: .permanent)

        let firstFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        try handler.removeProperty(key: "foo", lifespan: .permanent)

        let secondFetch = storage.fetchCustomPropertiesForSessionId(sessionController.currentSession!.id)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    // MARK: tmp core data
    func skip_test_coreDataClone() throws {
        // given previously stored metadata
        let baseUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        let sqliteFile = Bundle.module.path(forResource: "tmp_db", ofType: "sqlite", inDirectory: "Mocks")!
        let sqliteShmFile = Bundle.module.path(forResource: "tmp_db", ofType: "sqlite-shm", inDirectory: "Mocks")!
        let sqliteWalFile = Bundle.module.path(forResource: "tmp_db", ofType: "sqlite-wal", inDirectory: "Mocks")!

        try? FileManager.default.removeItem(atPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite").path)
        try FileManager.default.copyItem(
            atPath: sqliteFile,
            toPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite").path
        )

        try? FileManager.default.removeItem(
            atPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite-shm").path)
        try FileManager.default.copyItem(
            atPath: sqliteShmFile,
            toPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite-shm").path
        )

        try? FileManager.default.removeItem(
            atPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite-wal").path)
        try FileManager.default.copyItem(
            atPath: sqliteWalFile,
            toPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite-wal").path
        )

        storage = try EmbraceStorage.createInDiskDb(fileName: testName)

        // when initializing a metadata handler
        _ = MetadataHandler(storage: storage, sessionController: sessionController)

        // the temporary db data is cloned into the real storage
        let metadata: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(metadata.count, 4)

        let requiredResource = metadata.first(where: { $0.typeRaw == "requiredResource" })
        XCTAssertNotNil(requiredResource)
        XCTAssertEqual(requiredResource!.key, "required_resource")
        XCTAssertEqual(requiredResource!.value, "test")
        XCTAssertEqual(requiredResource!.lifespanRaw, "permanent")
        XCTAssertEqual(requiredResource!.lifespanId, "")

        let resource = metadata.first(where: { $0.typeRaw == "resource" })
        XCTAssertNotNil(resource)
        XCTAssertEqual(resource!.key, "resource")
        XCTAssertEqual(resource!.value, "test")
        XCTAssertEqual(resource!.lifespanRaw, "process")
        XCTAssertEqual(resource!.lifespanId, "12345")

        let property = metadata.first(where: { $0.typeRaw == "customProperty" })
        XCTAssertNotNil(property)
        XCTAssertEqual(property!.key, "property")
        XCTAssertEqual(property!.value, "test")
        XCTAssertEqual(property!.lifespanRaw, "session")
        XCTAssertEqual(property!.lifespanId, "54321")

        let personaTag = metadata.first(where: { $0.typeRaw == "personaTag" })
        XCTAssertNotNil(personaTag)
        XCTAssertEqual(personaTag!.key, "persona_tag")
        XCTAssertEqual(personaTag!.value, "test")
        XCTAssertEqual(personaTag!.lifespanRaw, "session")
        XCTAssertEqual(property!.lifespanId, "54321")

        // and the temporary db file is removed
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: baseUrl.appendingPathComponent("EmbraceMetadataTmp.sqlite").path))
    }

    func skip_test_coreDataClone_noFile() throws {
        // given no previously stored metadata
        storage = try EmbraceStorage.createInDiskDb(fileName: testName)

        // when initializing a metadata handler
        _ = MetadataHandler(storage: storage, sessionController: sessionController)

        // no data is cloned
        let metadata: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(metadata.count, 0)
    }
}
