//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

extension SessionRecordTests {

    func test_addSessionAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let expectation1 = XCTestExpectation()
        var session: SessionRecord?

        storage.addSessionAsync(id: "id", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil, crashReportId: nil) { result in
            switch result {
            case .success(let s):
                session = s
                expectation1.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // then session should exist in storage
        let expectation2 = XCTestExpectation()
        if let session = session {
            try storage.dbQueue.read { db in
                XCTAssert(try session.exists(db))
                expectation2.fulfill()
            }
        } else {
            XCTAssert(false, "session is invalid!")
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }

    func test_upsertSessionAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let expectation1 = XCTestExpectation()
        let session = SessionRecord(id: "id", state: .foreground, processId: UUID(), startTime: Date())

        storage.upsertSessionAsync(session) { result in
            switch result {
            case .success:
                expectation1.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try session.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchSessionAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session
        let original = try storage.addSession(id: "id", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil)

        // when fetching the session
        let expectation = XCTestExpectation()
        var session: SessionRecord?

        storage.fetchSessionAsync(id: "id") { result in
            switch result {
            case .success(let s):
                session = s
                expectation.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // then session should be valid
        XCTAssertEqual(original, session)
    }

    func test_updateSessionEndTimeAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session with nil endTime
        let original = try storage.addSession(id: "id", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil)
        XCTAssertNil(original.endTime)

        // when updating the session endtime
        let expectation1 = XCTestExpectation()
        var session: SessionRecord?

        storage.updateSessionAsync(id: "id", endTime: Date(timeIntervalSinceNow: 10)) { result in
            switch result {
            case .success(let s):
                session = s
                expectation1.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // then the session should be valid and be updated in storage
        let expectation2 = XCTestExpectation()
        if let session = session {
            try storage.dbQueue.read { db in
                XCTAssert(try session.exists(db))
                XCTAssertNotNil(session.endTime)
                expectation2.fulfill()
            }
        } else {
            XCTAssert(false, "session not found in storage!")
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }

    func test_updateSessionCrashReportIdAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted session with nil endTime
        let original = try storage.addSession(id: "id", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil)
        XCTAssertNil(original.endTime)

        // when updating the session endtime
        let expectation1 = XCTestExpectation()
        var session: SessionRecord?

        storage.updateSessionAsync(id: "id", crashReportId: "crashReportId") { result in
            switch result {
            case .success(let s):
                session = s
                expectation1.fulfill()
            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation1], timeout: .defaultTimeout)

        // then the session should be valid and be updated in storage
        let expectation2 = XCTestExpectation()
        if let session = session {
            try storage.dbQueue.read { db in
                XCTAssert(try session.exists(db))
                XCTAssertEqual(session.crashReportId, "crashReportId")
                expectation2.fulfill()
            }
        } else {
            XCTAssert(false, "session not found in storage!")
        }

        wait(for: [expectation2], timeout: .defaultTimeout)
    }

    func test_finishedSessionsCountAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted sessions
        _ = try storage.addSession(id: "id1", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil)
        _ = try storage.addSession(id: "id2", state: .foreground, processId: UUID(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))
        _ = try storage.addSession(id: "id3", state: .foreground, processId: UUID(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))

        // then the finished session count should be correct
        let expectation = XCTestExpectation()

        // when fetching the finished session count
        storage.finishedSessionsCountAsync { result in
            switch result {
            case .success(let count):
                // then the count is correct
                XCTAssertEqual(count, 2)
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchFinishedSessionsAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted sessions
        let session1 = try storage.addSession(id: "id1", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil)
        let session2 = try storage.addSession(id: "id2", state: .foreground, processId: UUID(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))
        let session3 = try storage.addSession(id: "id3", state: .foreground, processId: UUID(), startTime: Date(), endTime: Date(timeIntervalSinceNow: 10))

        // when fetching the finished sessions
        let expectation = XCTestExpectation()

        storage.fetchFinishedSessionsAsync { result in
            switch result {
            case .success(let sessions):
                // then the fetched sessions are valid
                XCTAssertFalse(sessions.contains(session1))
                XCTAssert(sessions.contains(session2))
                XCTAssert(sessions.contains(session3))
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchLatestSesssionAsync() throws {
        let storage = try EmbraceStorage(options: testOptions)

        // given inserted sessions
        _ = try storage.addSession(id: "id1", state: .foreground, processId: UUID(), startTime: Date(), endTime: nil)
        _ = try storage.addSession(id: "id2", state: .foreground, processId: UUID(), startTime: Date(timeIntervalSinceNow: 10), endTime: nil)
        let session3 = try storage.addSession(id: "id3", state: .foreground, processId: UUID(), startTime: Date(timeIntervalSinceNow: 20), endTime: nil)

        // when fetching the latest session
        let expectation = XCTestExpectation()

        storage.fetchLatestSesssionAsync { result in
            switch result {
            case .success(let session):
                // then the fetched session is valid
                XCTAssertEqual(session, session3)
                expectation.fulfill()

            case .failure(let error):
                XCTAssert(false, error.localizedDescription)
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
