//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceIO
import EmbraceStorage
import EmbraceCommon
import EmbraceOTel
import TestSupport

final class SessionControllerTests: XCTestCase {

    var storage: EmbraceStorage!
    var controller: SessionController!

    override func setUpWithError() throws {
        storage = try EmbraceStorage(options: .init(named: #file))
        controller = SessionController(storage: storage)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        storage = nil
        controller = nil
    }

    func test_createSession_returnsNewSessionEveryTime() throws {
        let a = controller.createSession(state: .foreground)
        let b = controller.createSession(state: .foreground)
        let c = controller.createSession(state: .foreground)

        XCTAssertNotEqual(a.id, b.id)
        XCTAssertNotEqual(a.id, c.id)
        XCTAssertNotEqual(b.id, c.id)
    }

    func test_createSession_setsForegroundState() throws {
        let a = controller.createSession(state: .foreground)
        XCTAssertEqual(a.state, .foreground)
    }

    func test_createSession_setsBackgroundState() throws {
        let a = controller.createSession(state: .background)
        XCTAssertEqual(a.state, .background)
    }

    // MARK: start(session:at:)

    func test_startSession_setsCurrentSession_andPostsDidStartNotification() throws {
        let session = controller.createSession(state: .foreground)
        XCTAssertNil(session.startAt)
        let notificationExpectation = expectation(forNotification: .embraceSessionDidStart, object: session)

        controller.start(session: session)

        XCTAssertNotNil(session.startAt)
        XCTAssertNotNil(controller.currentSessionSpan)
        XCTAssertEqual(controller.currentSession?.id, session.id)
        wait(for: [notificationExpectation])
    }

    func test_startSession_ifStartAtIsSoonAfterProcessStart_marksSessionAsColdStartTrue() throws {
        let processStart = ProcessMetadata.startTime!

        let session = controller.createSession(state: .foreground)
        controller.start(session: session, at: processStart)

        XCTAssertTrue(session.coldStart)
    }

    func test_startSession_ifStartAtMatchesAllowedColdStartInterval_marksSessionAsColdStartTrue() throws {
        let processStart = ProcessMetadata.startTime!
        let startAt = processStart.addingTimeInterval(SessionController.allowedColdStartInterval)

        let session = controller.createSession(state: .foreground)
        controller.start(session: session, at: startAt)

        XCTAssertTrue(session.coldStart)
    }

    func test_startSession_ifStartAtIsPassedAllowedColdStartInterval_marksSessionAsColdStartFalse() throws {
        let processStart = ProcessMetadata.startTime!
        let startAt = processStart.addingTimeInterval(SessionController.allowedColdStartInterval + 1)
        let session = controller.createSession(state: .foreground)

        controller.start(session: session, at: startAt)

        XCTAssertFalse(session.coldStart)
    }

    func test_startSession_ifStartAtIsBeforeProcessStart_marksSessionAsColdStartFalse() throws {
        let processStart = ProcessMetadata.startTime!
        let startAt = processStart.addingTimeInterval(-1)
        let session = controller.createSession(state: .foreground)

        controller.start(session: session, at: startAt)

        XCTAssertFalse(session.coldStart)
    }

    func test_startSession_saves_foregroundSession() throws {
        let session = controller.createSession(state: .foreground)

        controller.start(session: session)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id.toString)
        XCTAssertEqual(sessions.first?.state, "foreground")
    }

    func test_startSession_saves_backgroundSession() throws {
        let session = controller.createSession(state: .background)

        controller.start(session: session)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id.toString)
        XCTAssertEqual(sessions.first?.state, "background")
    }

    func test_startSession_startsSessionSpan() throws {
        let spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessor: spanProcessor)

        let session = controller.createSession(state: .foreground)

        // Call Start
        controller.start(session: session)

        if let spanData = spanProcessor.startedSpans.first {
            XCTAssertEqual(spanData.startTime.timeIntervalSince1970, session.startAt!.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertNil(spanData.endTime)
        }
    }

    // MARK: end(session:at:)

    func test_endSession_setsCurrentSessionToNil_andPostsWillEndNotification() throws {
        let session = controller.createSession(state: .foreground)
        controller.start(session: session)
        XCTAssertNotNil(controller.currentSessionSpan)
        XCTAssertNil(session.endAt)
        let notificationExpectation = expectation(forNotification: .embraceSessionWillEnd, object: session)

        controller.end(session: session)

        XCTAssertNotNil(session.endAt)
        XCTAssertNil(controller.currentSession)
        XCTAssertNil(controller.currentSessionSpan)
        wait(for: [notificationExpectation])
    }

    func test_endSession_saves_foregroundSession() throws {
        let session = controller.createSession(state: .foreground)
        controller.start(session: session)
        XCTAssertNil(session.endAt)

        let endAt = Date()
        controller.end(session: session, at: endAt)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id.toString)
        XCTAssertEqual(sessions.first?.state, "foreground")
        XCTAssertEqual(sessions.first!.endTime!.timeIntervalSince1970, endAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_endSession_saves_endsSessionSpan() throws {
        let spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessor: spanProcessor)

        let session = controller.createSession(state: .foreground)
        controller.start(session: session)

        // Call Start
        let endAt = Date(timeIntervalSinceNow: 5.0)
        controller.end(session: session, at: endAt)

        if let spanData = spanProcessor.endedSpans.first {
            XCTAssertEqual(spanData.endTime!.timeIntervalSince1970, endAt.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    // MARK: update(session:)

    func test_update_assignsState_toBackground_whenPresent() throws {
        let session = controller.createSession(state: .foreground)
        XCTAssertEqual(session.state, .foreground)

        controller.update(session: session, state: .background)
        XCTAssertEqual(session.state, .background)
    }

    func test_update_assignsState_toForeground_whenPresent() throws {
        let session = controller.createSession(state: .background)
        XCTAssertEqual(session.state, .background)

        controller.update(session: session, state: .foreground)
        XCTAssertEqual(session.state, .foreground)
    }

    func test_update_doesNot_assignState_whenNotPresent() throws {
        let session = controller.createSession(state: .background)
        XCTAssertEqual(session.state, .background)

        controller.update(session: session)
        XCTAssertEqual(session.state, .background)
    }

    func test_update_assignsAppTerminated_toFalse_whenPresent() throws {
        let session = controller.createSession(state: .foreground)
        session.appTerminated = true

        controller.update(session: session, appTerminated: false)
        XCTAssertEqual(session.appTerminated, false)
    }

    func test_update_assignsAppTerminated_toTrue_whenPresent() throws {
        let session = controller.createSession(state: .foreground)
        session.appTerminated = false

        controller.update(session: session, appTerminated: true)
        XCTAssertEqual(session.appTerminated, true)
    }

    func test_update_doesNot_assignAppTerminated_whenNotPresent() throws {
        let session = controller.createSession(state: .foreground)
        session.appTerminated = true

        controller.update(session: session)
        XCTAssertEqual(session.appTerminated, true)
    }

    func test_update_changesTo_appTerminated_saveInStorage() throws {
        let session = controller.createSession(state: .foreground)
        controller.start(session: session)
        session.appTerminated = false

        controller.update(session: session, appTerminated: true)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id.toString)
        XCTAssertEqual(sessions.first?.state, "foreground")
        XCTAssertEqual(sessions.first?.appTerminated, true)
    }

    func test_update_changesTo_sessionState_saveInStorage() throws {
        let session = controller.createSession(state: .foreground)
        controller.start(session: session)
        session.appTerminated = false

        controller.update(session: session, state: .background)

        let sessions: [SessionRecord] = try storage.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, session.id.toString)
        XCTAssertEqual(sessions.first?.state, "background")
        XCTAssertEqual(sessions.first?.appTerminated, false)
    }
}
