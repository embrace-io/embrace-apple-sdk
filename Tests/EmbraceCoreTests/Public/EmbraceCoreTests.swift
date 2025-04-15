//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceOTelInternal
import OpenTelemetrySdk

final class EmbraceCoreTests: XCTestCase {

    // this is used in the helper function
    private let lock: UnfairLock = UnfairLock()

    func test_ConcurrentCurrentSessionId() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        let sessionId = embrace?.currentSessionId()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the required
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            let cSessionId = embrace?.currentSessionId()
            XCTAssertEqual(cSessionId, sessionId)
        }

    }

    func test_ConcurrentCurrentSessionIdWhileEndingSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the required
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            embrace?.endCurrentSession()
            let id = embrace?.currentSessionId()
#if os(iOS)
            // iOS lifecycle restarts the session on every endCurrentSession call
            // so id should never be nil
            XCTAssertNotNil(id)
#else
            // Non-iOS lifecycle does not restart session so id should be nil
            XCTAssertNil(id)
#endif
        }
    }

    func test_ConcurrentCurrentSessionIdWhileStartingSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the required
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            let id = embrace?.currentSessionId()
            embrace?.startNewSession()
            XCTAssertNotNil(id)
        }
    }

    func test_ConcurrentEndSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        let sessionId = embrace?.currentSessionId()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the required
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            embrace?.endCurrentSession()
            let cSessionId = embrace?.currentSessionId()
            XCTAssertNotEqual(cSessionId, sessionId)
        }

        // added this for the non ios lifecycle case
        embrace?.startNewSession()
        let cSessionId = embrace?.currentSessionId()
        XCTAssertNotEqual(cSessionId, sessionId)
    }

    func test_ConcurrentStartSession() throws {
        let embrace = try getLocalEmbrace()
        try embrace?.start()
        let sessionId = embrace?.currentSessionId()

        // concurrentPerform performs concurrent operations in a synchronous manner on the called thread.
        // so it seems to be good for testing as it prevents the required
        // use of expectations
        DispatchQueue.concurrentPerform(iterations: 100) {_ in
            embrace?.startNewSession()
            let cSessionId = embrace?.currentSessionId()
            XCTAssertNotEqual(cSessionId, sessionId)
        }
    }

    func test_getLastRunEndState() throws {
        let crashReporter = CrashReporterMock()
        let embrace = try getLocalEmbrace(crashReporter: crashReporter)

        crashReporter.forcedLastRunState = .unavailable
        XCTAssertEqual(embrace?.lastRunEndState(), .unavailable)

        crashReporter.forcedLastRunState = .crash
        XCTAssertEqual(embrace?.lastRunEndState(), .crash)

        crashReporter.forcedLastRunState = .cleanExit
        XCTAssertEqual(embrace?.lastRunEndState(), .cleanExit)
    }

    func test_getLastRunEndState_noCrashReporter() throws {
        let embrace = try getLocalEmbrace()
        XCTAssertEqual(embrace?.lastRunEndState(), .unavailable)
    }

    func test_EmbraceStartNonMainThreadShouldThrow() throws {
        let embrace = try getLocalEmbrace()
        let expectation = self.expectation(description: "testWillNotDeadlock")

        DispatchQueue.global().async {
            // with the do / catch we get a warning but without it there is an error.
            // known bug - https://github.com/swiftlang/swift/issues/57281
            // best workaround is to use do / catch

            do {
                XCTAssertThrowsError(try embrace?.start()) { error in
                    XCTAssertEqual(
                        error as? EmbraceSetupError,
                        EmbraceSetupError.invalidThread("Embrace must be started on the main thread")
                    )
                }
            } catch let e {
                XCTFail("unexpected exception \(e.localizedDescription)")
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 100)
    }

    func test_sdkStates() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        XCTAssertTrue(embrace.state == .initialized)

        try embrace.start()
        XCTAssertTrue(embrace.state == .started)

        try embrace.stop()
        XCTAssertTrue(embrace.state == .stopped)
    }

    func test_stop_withoutStart() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        try embrace.stop()

        XCTAssertTrue(embrace.state == .initialized)
    }

    func test_startAfterStop() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        try embrace.start()
        try embrace.stop()
        try embrace.start()

        XCTAssertTrue(embrace.state == .stopped)
    }

    func test_multipleStops() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        try embrace.start()
        try embrace.stop()
        try embrace.stop()
        try embrace.stop()
    }

    func test_EmbraceStartOnMainThreadShouldNotThrow() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        try embrace.start()

        XCTAssertTrue(embrace.state == .started)
    }

    func test_EmbraceStart_defaultLogLevelIsDebug() throws {
        guard let embrace = try getLocalEmbrace() else {
            XCTFail("failed to get embrace instance")
            return
        }

        try embrace.start()

        XCTAssertEqual(embrace.logLevel, .debug)
    }

    func test_flushSpan_AddEventToSessionSpan() throws {
        // Given an Embrace client.
        let storage = try EmbraceStorage.createInMemoryDb()
        guard let embrace = try getLocalEmbrace(storage: storage) else {
            XCTFail("\(#function): failed to get embrace instance")
            return
        }

        try embrace.start()

        // When adding an event to the Session Span.
        embrace.add(event: Breadcrumb(message: "Test Breadcrumb", attributes: [:]))

        // Check the event was flushed to storage immediately after.
        try storage.dbQueue.inDatabase { db in
            let records = try SpanRecord.fetchAll(db)
            if let sessionSpan = records.first(where: { $0.name == "emb-session" }) {
                let spanData = try JSONDecoder().decode(SpanData.self, from: sessionSpan.data)
                let breadcrumbEvent = spanData.events.first(where: {
                    $0.name == "emb-breadcrumb" &&
                    $0.attributes["message"] == .string("Test Breadcrumb")
                })
                XCTAssertNotNil(breadcrumbEvent)
            } else {
                XCTFail("\(#function): Failed, no session span found on storage.")
            }
        }
    }

    func test_ManualSpanExport() throws {
        throw XCTSkip("Need to figure out how to setup the sdk state provider so the span processor works.")

        // Given an Embrace client.
        let storage = try EmbraceStorage.createInMemoryDb()
        guard let embrace = try getLocalEmbrace(storage: storage) else {
            XCTFail("\(#function): failed to get embrace instance")
            return
        }

        let span = embrace.buildSpan(name: "test_manual_export_span").startSpan()

        embrace.flush(span)

        try storage.dbQueue.inDatabase { db in
            let records = try SpanRecord.fetchAll(db)
            if let sessionSpan = records.first(where: { $0.name == "test_manual_export_span" }) {
                let spanData = try JSONDecoder().decode(SpanData.self, from: sessionSpan.data)
                XCTAssertFalse(spanData.hasEnded)
            } else {
                XCTFail("\(#function): Failed, span not found in storage.")
            }
        }
    }

    // MARK: - Crash+CrashRecorder tests
    func test_appendCrashInfo_throwsOnNotHavingCrashReporter() throws {
        let embrace = try getLocalEmbrace(crashReporter: nil)

        XCTAssertThrowsError(try embrace?.appendCrashInfo(key: .random(), value: .random()))
    }

    func test_appendCrashInfo_throwsOnNotAnExtendableCrashReporter() throws {
        let crashReporter = CrashReporterMock()
        let embrace = try getLocalEmbrace(crashReporter: crashReporter)

        XCTAssertThrowsError(try embrace?.appendCrashInfo(key: .random(), value: .random()))
    }

    func test_appendCrashInfo_forwardsToReporterToAddTheGivenInfo() throws {
        let crashReporter = ExtendableCrashReporterMock()
        let embrace = try getLocalEmbrace(crashReporter: crashReporter)

        XCTAssertNoThrow(try embrace?.appendCrashInfo(key: .random(), value: .random()))
        XCTAssertTrue(crashReporter.didCallAppendCrashInfo)
    }

    // MARK: - Helper Methods
    func getLocalEmbrace(storage: EmbraceStorage? = nil, crashReporter: CrashReporter? = nil) throws -> Embrace? {
        // to ensure that each test gets it's own instance of embrace.
        return try lock.locked {

            // use fake endpoints
            let endpoints = Embrace.Endpoints(
                baseURL: "https://embrace.\(testName).com/api",
                configBaseURL: "https://embrace.\(testName).com/config"
            )

            // I use random string for group id to ensure a different storage location each time
            let options = Embrace.Options(
                appId: "testA",
                appGroupId: randomString(length: 5),
                endpoints: endpoints,
                captureServices: [],
                crashReporter: crashReporter
            )

            try Embrace.client = Embrace(options: options, embraceStorage: storage)
            XCTAssertNotNil(Embrace.client)

            let embrace = Embrace.client
            Embrace.client = nil
            
            return embrace
        }
    }

    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
