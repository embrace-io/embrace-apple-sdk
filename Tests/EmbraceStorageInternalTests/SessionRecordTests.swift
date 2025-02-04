//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommonInternal
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
        XCTAssertEqual(sessions[0].idRaw, TestConstants.sessionId.toString)
    }

    func test_fetchSession() throws {
        // given inserted session
        let sessionId = SessionIdentifier.random
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
        XCTAssertEqual(original, session)
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
        XCTAssertEqual(session, session3)
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
        XCTAssertEqual(session, session1)
    }
}
