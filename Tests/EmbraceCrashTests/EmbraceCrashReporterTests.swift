//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

// on watchOS, KSCrash only supports exception..
// Due to this, there's no crash support on watchOS.
#if !os(watchOS)

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceKSCrashSupport

class EmbraceCrashReporterTests: XCTestCase {

    let logger = MockLogger()
    var context: CrashReporterContext = .testContext
    var crashReporter: EmbraceCrashReporter!

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: context.filePathProvider.directoryURL(for: "embrace_crash_reporter")!)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: context.filePathProvider.directoryURL(for: "embrace_crash_reporter")!)
    }

    func test_currentSessionId() {
        givenCrashReporter()

        // when setting the current session id
        let sessionId = SessionIdentifier.random
        crashReporter.currentSessionId = sessionId.toString

        // then KSCrash's user info is properly set
        XCTAssertEqual(crashReporter.getCrashInfo(key: CrashReporterInfoKey.sessionId), sessionId.toString)
    }

    func test_sdkVersion() {
        givenCrashReporter()

        // then KSCrash's user info is properly set
        XCTAssertEqual(crashReporter.getCrashInfo(key: CrashReporterInfoKey.sdkVersion), TestConstants.sdkVersion)
    }

    func test_fetchCrashReports() throws {
        givenCrashReporter()

        // given some fake crash report
        try copyReport(named: "crash_report", toFilePath: "/Reports/appId-report-0000000000000001.json")

        // then the report is fetched
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 1)
            XCTAssertEqual(reports[0].sessionId, TestConstants.sessionId.toString)
            XCTAssertNotNil(reports[0].timestamp)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchCrashReports_count() throws {
        givenCrashReporter()

        // given some fake crash report
        for i in 1...9 {
            try copyReport(named: "crash_report", toFilePath: "/Reports/appId-report-000000000000000\(i).json")
        }

        // then the report is fetched
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 9)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_appendCrashInfo_addsKeyValuesInKSCrashUserInfo() throws {
        givenCrashReporter()

        crashReporter.appendCrashInfo(key: "some", value: "value")

        XCTAssertEqual(try XCTUnwrap(crashReporter.getCrashInfo(key: "some")), "value")
    }

    func test_appendCrashInfo_addsDefaultInfoWhenBeingCalled() throws {
        givenCrashReporter()

        crashReporter.appendCrashInfo(key: "some", value: "value")

        for expectedKey in ["emb-sdk", "emb-sid"] {
            XCTAssertNotNil(crashReporter.getCrashInfo(key: expectedKey))
        }
    }

    func testInKSCrash_appendCrashInfo_shouldntDeletePreexistingKeys() throws {
        givenCrashReporter()
        crashReporter.appendCrashInfo(key: "initial_key", value: "one_value")
        crashReporter.appendCrashInfo(key: "some", value: "value")

        for expectedKey in ["emb-sdk", "emb-sid"] {
            XCTAssertNotNil(crashReporter.getCrashInfo(key: expectedKey))
        }
        XCTAssertEqual(crashReporter.getCrashInfo(key: "initial_key"), "one_value")
    }

    func testHavingInternalAddedInfoInKSCrash_appendCrashInfo_shouldntEraseThoseValues() throws {
        // given crash reporter with an already set sdkVersion and sessionId
        crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), logger: logger)
        let context = CrashReporterContext(
            appId: "_-_-_",
            sdkVersion: "1.2.3",
            filePathProvider: TemporaryFilepathProvider(),
            notificationCenter: .default
        )
        crashReporter.install(context: context)
        crashReporter.currentSessionId = "original_session_id"

        // [Intermediate Assertion to ensure the `given` state]
        XCTAssertEqual(crashReporter.getCrashInfo(key: "emb-sid"), "original_session_id")
        XCTAssertEqual(crashReporter.getCrashInfo(key: "emb-sdk"), "1.2.3")

        // When trying to change the internal (necessary) properties from kscrash
        crashReporter.appendCrashInfo(key: "emb-sid", value: "maliciously_updated_session_id")
        crashReporter.appendCrashInfo(key: "emb-sdk", value: "1.2.3-broken")

        // Then values should remain untouched
        XCTAssertNotEqual(crashReporter.getCrashInfo(key: "emb-sid"), "maliciously_updated_session_id")
        XCTAssertNotEqual(crashReporter.getCrashInfo(key: "emb-sdk"), "1.2.3-broken")
    }

    func testHavingInternalAddedInfoFunctions() throws {
        
        crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), logger: logger)
        let context = CrashReporterContext(
            appId: "_-_-_",
            sdkVersion: "1.2.3",
            filePathProvider: TemporaryFilepathProvider(),
            notificationCenter: .default
        )
        crashReporter.install(context: context)
        
        crashReporter.currentSessionId = "original_session_id"
        XCTAssertEqual(crashReporter.currentSessionId, "original_session_id")
        XCTAssertEqual(crashReporter.getCrashInfo(key: CrashReporterInfoKey.sessionId), "original_session_id")
        
        crashReporter.appendCrashInfo(key: CrashReporterInfoKey.sessionId, value: "nope")
        XCTAssertEqual(crashReporter.currentSessionId, "original_session_id")
        XCTAssertEqual(crashReporter.getCrashInfo(key: CrashReporterInfoKey.sessionId), "original_session_id")
        
        crashReporter.appendCrashInfo(key: "key1", value: "value1")
        XCTAssertEqual(crashReporter.getCrashInfo(key: "key1"), "value1")
    }
    
    // MARK: - Signal Block List Tests

    func testOnHavingDefaultSignalBlockList_fetchUnsentCrashReports_SIGTERMshouldntBeReported() throws {
        // given a crash reporter
        givenCrashReporter()

        // given some fake crash reports (non-blocked & blocked [SIGTERM])
        try copyReport(named: "sigabrt_report", toFilePath: "/Reports/appId-report-0000000000000001.json")
        try copyReport(named: "sigterm_report", toFilePath: "/Reports/appId-report-0000000000000002.json")

        let expectation = XCTestExpectation()

        // when fetching unsent crash reports
        crashReporter.fetchUnsentCrashReports { reports in
            // Then only one report should be present
            XCTAssertEqual(reports.count, 1)
            // and report shouldn't be the one with the SIGTERM signal
            XCTAssertEqual(reports[0].internalId, 1)
            // and dropped report should have been deleted
            self.thenShouldntExistReport(withName: "appId-report-0000000000000002.json")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testOnHavingEmptySignalBlockList_fetchUnsentCrashReports_SIGTERMshouldBeReported() throws {
        // given a crash reporter with no blocklist
        crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), signalsBlockList: [])
        crashReporter.install(context: context)

        // given some fake crash reports (SIGABRT + SIGTERM)
        try copyReport(named: "sigabrt_report", toFilePath: "/Reports/appId-report-0000000000000001.json")
        try copyReport(named: "sigterm_report", toFilePath: "/Reports/appId-report-0000000000000002.json")

        let expectation = XCTestExpectation()

        // when fetching unsent crash reports
        crashReporter.fetchUnsentCrashReports { reports in
            // Then both reports should be present
            XCTAssertEqual(reports.count, 2)
            XCTAssertEqual(reports[0].internalId, 1)
            XCTAssertEqual(reports[1].internalId, 2)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func testOnModifyingSignalBlockList_fetchUnsentCrashReports_shouldAvoidReportingBlockedSignals() throws {
        // given a crash reporter preventing SIGABRT from being reported
        crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), signalsBlockList: [.SIGABRT])
        crashReporter.install(context: context)

        // given some fake crash reports (nonBlocked SIGTERM + blocked SIGABRT)
        try copyReport(named: "sigabrt_report", toFilePath: "/Reports/appId-report-0000000000000001.json")
        try copyReport(named: "sigterm_report", toFilePath: "/Reports/appId-report-0000000000000002.json")

        let expectation = XCTestExpectation()

        // when fetching unsent crash reports
        crashReporter.fetchUnsentCrashReports { reports in
            // Then only one report should be
            XCTAssertEqual(reports.count, 1)
            // and report shouldn't be the one with the SIGABRT signal
            XCTAssertEqual(reports[0].internalId, 2)
            // and dropped report should have been deleted
            self.thenShouldntExistReport(withName: "appId-report-0000000000000001.json")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}

extension EmbraceCrashReporterTests {
    fileprivate func copyReport(named: String, toFilePath: String) throws {
        let basePath = try XCTUnwrap(crashReporter.basePath)
        if !FileManager.default.fileExists(atPath: basePath) {
            try FileManager.default.createDirectory(
                atPath: basePath + "/Reports",
                withIntermediateDirectories: true
            )
        }
        let report = try XCTUnwrap(Bundle.module.path(forResource: named, ofType: "json", inDirectory: "Mocks"))
        try FileManager.default.copyItem(atPath: report, toPath: basePath + toFilePath)
    }

    fileprivate func thenShouldntExistReport(withName name: String) {
        do {
            let basePath = try XCTUnwrap(crashReporter.basePath)
            XCTAssertFalse(FileManager.default.fileExists(atPath: basePath + "/Reports/" + name))
        } catch let ex {
            XCTFail(ex.localizedDescription)
        }
    }

    fileprivate func givenCrashReporter() {
        crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), logger: logger)
        crashReporter.currentSessionId = UUID().uuidString
        crashReporter.install(context: context)
    }
}

#endif
