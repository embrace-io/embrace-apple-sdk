//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceStorageInternal

class SessionRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()
    }

    override func tearDownWithError() throws {
        storage.coreData.destroy()
    }

    func test_addSession() throws {
        // given inserted session
        storage.addSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // then session should exist in storage
        let sessions: [SessionRecord] = storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].idRaw, TestConstants.sessionId.stringValue)
    }

    func test_addSession_storesSessionNumber() throws {
        // given a session inserted with an explicit sessionNumber
        let sessionId = EmbraceIdentifier.random
        storage.addSession(
            id: sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(),
            sessionNumber: 3
        )

        // when fetching the session back from storage
        let session = storage.fetchSession(id: sessionId)

        // then the sessionNumber is persisted correctly
        XCTAssertEqual(session?.sessionNumber, 3)
    }

    func test_fetchSession() throws {
        // given inserted session
        let sessionId = EmbraceIdentifier.random
        let original = storage.addSession(
            id: sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // when fetching the session
        let session = storage.fetchSession(id: sessionId)

        // then the session should be valid
        XCTAssertNotNil(session)
        XCTAssertEqual(original!.id, session!.id)
        XCTAssertEqual(original!.traceId, session!.traceId)
        XCTAssertEqual(original!.spanId, session!.spanId)
        XCTAssertEqual(original!.processId, session!.processId)
        XCTAssertEqual(original!.state, session!.state)
    }

    func test_fetchLatestSesssion() throws {
        // given inserted sessions
        storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 10)
        )
        let session3 = storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 20)
        )

        // when fetching the latest session
        let session = storage.fetchLatestSession()

        // then the fetched session is valid
        XCTAssertEqual(session!.id, session3!.id)
        XCTAssertEqual(session!.traceId, session3!.traceId)
        XCTAssertEqual(session!.spanId, session3!.spanId)
        XCTAssertEqual(session!.processId, session3!.processId)
        XCTAssertEqual(session!.state, session3!.state)
    }

    func test_fetchOldestSession() throws {
        // given inserted sessions
        let session1 = storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 10)
        )
        storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 20)
        )

        // when fetching the oldest session
        let session = storage.fetchOldestSession()

        // then the fetched session is valid
        XCTAssertEqual(session!.id, session1!.id)
        XCTAssertEqual(session!.traceId, session1!.traceId)
        XCTAssertEqual(session!.spanId, session1!.spanId)
        XCTAssertEqual(session!.processId, session1!.processId)
        XCTAssertEqual(session!.state, session1!.state)
    }

    // MARK: - User-session columns (v7)

    func test_addSession_legacyCallSiteOmitsUserSessionColumns_persistsNilDefaults() throws {
        // given a part inserted via the legacy call signature (no user-session args)
        let sessionId = EmbraceIdentifier.random
        storage.addSession(
            id: sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // when fetching the part back
        let session = try XCTUnwrap(storage.fetchSession(id: sessionId))

        // then all the v7 user-session columns are nil / 0
        XCTAssertNil(session.userSessionId)
        XCTAssertNil(session.userSessionStartTime)
        XCTAssertNil(session.userSessionMaxDuration)
        XCTAssertNil(session.userSessionInactivityTimeout)
        XCTAssertNil(session.userSessionLastForegroundEnd)
        XCTAssertEqual(session.userSessionPartIndex, 0)
        XCTAssertNil(session.userSessionEndReason)
    }

    func test_addSession_persistsUserSessionColumnsRoundTrip() throws {
        // given a part inserted with full user-session metadata
        let partId = EmbraceIdentifier.random
        let userSessionId = EmbraceIdentifier.random
        let userStart = Date(timeIntervalSince1970: 1_730_000_000)
        let lastFgEnd = Date(timeIntervalSince1970: 1_730_001_000)

        storage.addSession(
            id: partId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 1_730_002_000),
            sessionNumber: 42,
            userSessionId: userSessionId,
            userSessionStartTime: userStart,
            userSessionMaxDuration: 43200,
            userSessionInactivityTimeout: 1800,
            userSessionLastForegroundEnd: lastFgEnd,
            userSessionPartIndex: 3,
            userSessionEndReason: nil
        )

        // when fetching the part back
        let session = try XCTUnwrap(storage.fetchSession(id: partId))

        // then every user-session field round-trips exactly
        XCTAssertEqual(session.userSessionId, userSessionId)
        XCTAssertEqual(session.userSessionStartTime, userStart)
        XCTAssertEqual(session.userSessionMaxDuration, 43200)
        XCTAssertEqual(session.userSessionInactivityTimeout, 1800)
        XCTAssertEqual(session.userSessionLastForegroundEnd, lastFgEnd)
        XCTAssertEqual(session.userSessionPartIndex, 3)
        XCTAssertNil(session.userSessionEndReason)
        XCTAssertEqual(session.sessionNumber, 42)
    }

    func test_updateSession_setsUserSessionLastForegroundEnd_leavesOtherFieldsAlone() throws {
        // given a part with full user-session metadata
        let partId = EmbraceIdentifier.random
        let userSessionId = EmbraceIdentifier.random
        let userStart = Date(timeIntervalSince1970: 1_730_000_000)

        let original = try XCTUnwrap(
            storage.addSession(
                id: partId,
                processId: ProcessIdentifier.current,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(timeIntervalSince1970: 1_730_002_000),
                sessionNumber: 7,
                userSessionId: userSessionId,
                userSessionStartTime: userStart,
                userSessionMaxDuration: 43200,
                userSessionInactivityTimeout: 1800,
                userSessionPartIndex: 1
            ))

        // when updating only userSessionLastForegroundEnd
        let newFgEnd = Date(timeIntervalSince1970: 1_730_003_000)
        storage.updateSession(
            session: original,
            userSessionLastForegroundEnd: newFgEnd
        )

        // then the field is persisted and other user-session fields are unchanged
        let updated = try XCTUnwrap(storage.fetchSession(id: partId))
        XCTAssertEqual(updated.userSessionLastForegroundEnd, newFgEnd)
        XCTAssertEqual(updated.userSessionId, userSessionId)
        XCTAssertEqual(updated.userSessionStartTime, userStart)
        XCTAssertEqual(updated.userSessionMaxDuration, 43200)
        XCTAssertEqual(updated.userSessionInactivityTimeout, 1800)
        XCTAssertEqual(updated.userSessionPartIndex, 1)
        XCTAssertNil(updated.userSessionEndReason)
        XCTAssertEqual(updated.sessionNumber, 7)
    }

    func test_updateSession_setsUserSessionEndReason() throws {
        // given a part attached to a user session
        let partId = EmbraceIdentifier.random
        let original = try XCTUnwrap(
            storage.addSession(
                id: partId,
                processId: ProcessIdentifier.current,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(),
                userSessionId: .random,
                userSessionStartTime: Date(),
                userSessionMaxDuration: 43200,
                userSessionInactivityTimeout: 1800,
                userSessionPartIndex: 1
            ))

        // when stamping userSessionEndReason
        storage.updateSession(
            session: original,
            userSessionEndReason: TerminationReason.maxDurationReached.rawValue
        )

        // then the field is persisted
        let updated = try XCTUnwrap(storage.fetchSession(id: partId))
        XCTAssertEqual(updated.userSessionEndReason, "max_duration_reached")
    }

    func test_fetchLatestSession_returnsLatestWithUserSessionColumns() throws {
        // given two parts of the same user session, the second more recent
        let userSessionId = EmbraceIdentifier.random
        let userStart = Date(timeIntervalSince1970: 1_730_000_000)

        storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 1_730_001_000),
            sessionNumber: 5,
            userSessionId: userSessionId,
            userSessionStartTime: userStart,
            userSessionMaxDuration: 43200,
            userSessionInactivityTimeout: 1800,
            userSessionPartIndex: 1
        )
        storage.addSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .background,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 1_730_002_000),
            sessionNumber: 5,
            userSessionId: userSessionId,
            userSessionStartTime: userStart,
            userSessionMaxDuration: 43200,
            userSessionInactivityTimeout: 1800,
            userSessionPartIndex: 2
        )

        // when fetching the latest part
        let latest = try XCTUnwrap(storage.fetchLatestSession())

        // then the user-session metadata reflects the second part's view of the same user session
        XCTAssertEqual(latest.userSessionId, userSessionId)
        XCTAssertEqual(latest.userSessionStartTime, userStart)
        XCTAssertEqual(latest.userSessionPartIndex, 2)
        XCTAssertEqual(latest.sessionNumber, 5)
    }

    func test_entityDescription_includesUserSessionAttributes() throws {
        // given the SessionRecord entity description
        let entity = SessionRecord.entityDescription

        // then it carries each of the v7 user-session columns
        let names = Set(entity.properties.map { $0.name })
        XCTAssertTrue(names.contains("userSessionIdRaw"))
        XCTAssertTrue(names.contains("userSessionStartTime"))
        XCTAssertTrue(names.contains("userSessionMaxDuration"))
        XCTAssertTrue(names.contains("userSessionInactivityTimeout"))
        XCTAssertTrue(names.contains("userSessionLastForegroundEnd"))
        XCTAssertTrue(names.contains("userSessionPartIndex"))
        XCTAssertTrue(names.contains("userSessionEndReason"))
    }
}
