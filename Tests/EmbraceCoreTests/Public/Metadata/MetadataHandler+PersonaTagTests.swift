//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class MetadataHandler_PersonaTagTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionController: MockSessionController!

    static let invalidLength = PersonaTag(String(repeating: "a", count: PersonaTag.maxPersonaTagLength + 1))

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

    // MARK: - Add Personas

    func test_value_validation() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // when adding a persona tag with invalid value
        let expectation1 = XCTestExpectation()
        XCTAssertThrowsError(try handler.add(persona: Self.invalidLength)) { error in

            // then it should error out as a MetadataError.invalidValue
            switch error {
            case MetadataError.invalidValue:
                expectation1.fulfill()
            default:
                XCTAssert(false)
            }
        }

        wait(for: [expectation1], timeout: .defaultTimeout)
    }

    func test_limit_validation() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // given limits reached on persona tags
        for i in 1...storage.options.personaTagsLimit {
            storage.addMetadata(key: "test\(i)", value: "test\(i)", type: .personaTag, lifespan: .permanent)
        }

        // when adding a persona tag
        try handler.add(persona: "test", lifespan: .session)

        let metadata: [MetadataRecord] = storage.fetchAll()
        XCTAssertEqual(
            metadata.filter({ $0.typeRaw == MetadataRecordType.personaTag.rawValue }).count,
            storage.options.personaTagsLimit)
    }

    // MARK: - Current Personas
    @available(*, deprecated)
    func test_currentPersonas_returnsCorrectPersonas() throws {
        // given a metadata handler
        let handler = MetadataHandler(storage: storage, sessionController: sessionController)

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when fetching the current persona tags
        let tags = handler.currentPersonas

        // then the tags are correct
        XCTAssertEqual(tags.count, 3)
        XCTAssertEqual(Set(tags.map(\.rawValue)), Set(["permanent", "process", "session"]))
    }

    func test_getCurrentPersonasAsync_returnsCorrectPersonas() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )
        let expectation = expectation(description: #function)

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when fetching the current persona tags
        handler.getCurrentPersonas { tags in
            // then the tags are correct
            XCTAssertEqual(Set(tags.map(\.rawValue)), Set(["permanent", "process", "session"]))
            XCTAssertEqual(tags.count, 3)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    @available(*, deprecated)
    func test_getCurrentPersonas_returnsCorrectPersonas() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: "permanent",
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: "process",
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: "session",
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when fetching the current persona tags
        let tags = handler.getCurrentPersonas()

        // then the tags are correct
        XCTAssertEqual(tags.count, 3)
        XCTAssertEqual(Set(tags), Set(["permanent", "process", "session"]))
    }

    @available(*, deprecated)
    func test_getCurrentPersonas_withDifferentProcessIdentifier_returnsCorrectPersonas() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: "permanent",
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: "process",
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.random.value
        )
        storage.addMetadata(
            key: "session",
            value: "session",
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when fetching the current persona tags
        let tags = handler.getCurrentPersonas()

        // then the tags are correct
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(Set(tags), Set(["permanent", "session"]))
    }

    @available(*, deprecated)
    func test_currentPersonas_afterRemovingOne_returnsCorrectPersonas() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        storage.removeMetadata(key: "permanent", type: .personaTag, lifespan: .permanent, lifespanId: "")

        // when fetching the current persona tags
        let tags = handler.currentPersonas

        // then the tags are correct
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(Set(tags.map(\.rawValue)), Set(["process", "session"]))
    }

    // MARK: - Remove Persona

    func test_removePersona_worksWhenLifespanIsExplicit() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when removing a persona tag
        try handler.remove(persona: "session", lifespan: .session)

        // then the persona tag is removed
        let tags = storage.fetchPersonaTagsForSessionId(sessionController.currentSession!.id!)
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(Set(tags.map(\.key)), Set(["permanent", "process"]))
    }

    func test_removePersona_doesNotRemove_whenLifespanDoesNotMatch() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when removing a persona tag
        try handler.remove(persona: "permanent", lifespan: .session)

        // then the persona tag is removed
        let tags = storage.fetchPersonaTagsForSessionId(sessionController.currentSession!.id!)
        XCTAssertEqual(tags.count, 3)
        XCTAssertEqual(Set(tags.map(\.key)), Set(["permanent", "process", "session"]))
    }

    // MARK: - Remove All Personas
    func test_removeAllPersonas_withNoLifespanPassed_removesEverything() {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when removing all persona tags
        handler.removeAllPersonas()

        // then the persona tags are removed
        let tags = storage.fetchPersonaTagsForSessionId(sessionController.currentSession!.id!)
        XCTAssertEqual(tags.count, 0)
    }

    func test_removeAllPersonas_withLifespanPassed_removesOnlyMatchingLifespan() throws {
        // given a metadata handler
        let handler = MetadataHandler(
            storage: storage,
            sessionController: sessionController,
            syncronizationQueue: MockQueue()
        )

        // given some persona tags in storage
        storage.addMetadata(
            key: "permanent",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "process",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.value
        )
        storage.addMetadata(
            key: "session",
            value: PersonaTag.metadataValue,
            type: .personaTag,
            lifespan: .session,
            lifespanId: sessionController.currentSession!.idRaw
        )

        // when removing all persona tags
        handler.removeAllPersonas(lifespans: [.permanent])

        // then the persona tags are removed
        let tags = storage.fetchPersonaTagsForSessionId(sessionController.currentSession!.id!)
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(Set(tags.map(\.key)), Set(["process", "session"]))
    }
}
