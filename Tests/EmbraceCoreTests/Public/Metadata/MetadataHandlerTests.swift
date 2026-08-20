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
        handler.addProperty(key: "foo", value: "bar", lifespan: .userSession)

        let firstFetch = storage.fetchCustomProperties(for: sessionController.currentSession!)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        handler.removeProperty(key: "foo", lifespan: .userSession)

        let secondFetch = storage.fetchCustomProperties(for: sessionController.currentSession!)
        let result = secondFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNil(result)
    }

    func test_remove_removesMetadataWithUserSessionLifespan_acrossSessionParts() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        let firstPart = try XCTUnwrap(sessionController.currentSession)

        // when added during the first part of the user session
        handler.addProperty(key: "foo", value: "bar", lifespan: .userSession)

        // and a new part of the same user session starts
        let secondPart = try XCTUnwrap(sessionController.startSession(state: .background))
        XCTAssertEqual(firstPart.userSessionId, secondPart.userSessionId)

        // then the property is visible from the new part
        let fetch1 = storage.fetchCustomProperties(for: secondPart)
        XCTAssertNotNil(fetch1.first { $0.key == "foo" })

        // and removing it from the new part removes it for the whole user session
        handler.removeProperty(key: "foo", lifespan: .userSession)

        XCTAssertNil(storage.fetchCustomProperties(for: secondPart).first { $0.key == "foo" })
        XCTAssertNil(storage.fetchCustomProperties(for: firstPart).first { $0.key == "foo" })
    }

    func test_remove_doesNot_removeMetadataWithUserSessionLifespan_whenUserSessionChanges() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        let firstPart = try XCTUnwrap(sessionController.currentSession)

        // when added to the first user session
        handler.addProperty(key: "foo", value: "bar", lifespan: .userSession)

        // and a new user session starts
        let secondPart = try XCTUnwrap(sessionController.startNewUserSession(state: .foreground))
        XCTAssertNotEqual(firstPart.userSessionId, secondPart.userSessionId)

        // then the property doesn't apply to the new user session
        XCTAssertNil(storage.fetchCustomProperties(for: secondPart).first { $0.key == "foo" })
        XCTAssertNotNil(storage.fetchCustomProperties(for: firstPart).first { $0.key == "foo" })

        // and removing it can't reach the previous user session
        handler.removeProperty(key: "foo", lifespan: .userSession)

        XCTAssertNil(storage.fetchCustomProperties(for: secondPart).first { $0.key == "foo" })
        XCTAssertNotNil(storage.fetchCustomProperties(for: firstPart).first { $0.key == "foo" })
    }

    func test_addProperty_withUserSessionLifespan_isDropped_whenNoActiveUserSession() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        let part = try XCTUnwrap(sessionController.currentSession)

        // when there's no active user session, even though a part is still open
        sessionController.currentUserSession = nil
        handler.addProperty(key: "foo", value: "bar", lifespan: .userSession)

        // then the property is dropped
        XCTAssertNil(storage.fetchCustomProperties(for: part).first { $0.key == "foo" })
    }

    func test_remove_removesMetadata_withProcessLifespan() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // when added
        handler.addProperty(key: "foo", value: "bar", lifespan: .process)

        let firstFetch = storage.fetchCustomProperties(for: sessionController.currentSession!)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        handler.removeProperty(key: "foo", lifespan: .process)

        let secondFetch = storage.fetchCustomProperties(for: sessionController.currentSession!)
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
        handler.removeProperty(key: "foo", lifespan: .process)

        // exists in the other process
        let fetch1 = storage.fetchCustomProperties(userSessionId: nil, processId: otherProcessId)
        let result1 = fetch1.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(result1)

        // does not exist in current session
        let fetch2 = storage.fetchCustomProperties(for: sessionController.currentSession!)
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
        handler.addProperty(key: "foo", value: "bar", lifespan: .permanent)

        let firstFetch = storage.fetchCustomProperties(for: sessionController.currentSession!)
        let item = firstFetch.first { record in
            record.key == "foo"
        }
        XCTAssertNotNil(item)

        // When removed
        handler.removeProperty(key: "foo", lifespan: .permanent)

        let secondFetch = storage.fetchCustomProperties(for: sessionController.currentSession!)
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

    // MARK: Key / value validation

    func test_addProperty_keyExceedingMaxLength_isDropped() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // a key at the 128-char limit is stored
        let okKey = String(repeating: "k", count: 128)
        handler.addProperty(key: okKey, value: "v", lifespan: .userSession)

        // a key over the limit (129) is dropped
        let longKey = String(repeating: "k", count: 129)
        handler.addProperty(key: longKey, value: "v", lifespan: .userSession)

        let records = storage.fetchCustomProperties(for: sessionController.currentSession!)
        XCTAssertNotNil(records.first { $0.key == okKey })
        XCTAssertNil(records.first { $0.key == longKey })
    }

    func test_addProperty_valueExceedingMaxLength_isTruncatedWithEllipsis() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        handler.addProperty(key: "big", value: String(repeating: "a", count: 2000), lifespan: .userSession)

        // first 1020+1 characters are preserved, then an ellipsis is appended -> 1024 chars total
        let record = storage.fetchCustomProperties(for: sessionController.currentSession!)
            .first { $0.key == "big" }
        XCTAssertEqual(record?.value, String(repeating: "a", count: 1021) + "...")
    }

    func test_addProperty_valueAtMaxLength_isStoredUnchanged() throws {
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        let value = String(repeating: "a", count: 1024)
        handler.addProperty(key: "exact", value: value, lifespan: .userSession)

        let record = storage.fetchCustomProperties(for: sessionController.currentSession!)
            .first { $0.key == "exact" }
        XCTAssertEqual(record?.value, value)
    }
}
