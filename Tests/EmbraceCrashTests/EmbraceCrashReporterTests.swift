//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommonInternal
@testable import EmbraceCrash

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
        let key = "emb-sid"
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, sessionId.toString)
    }

    func test_sdkVersion() {
        givenCrashReporter()

        // then KSCrash's user info is properly set
        let key = "emb-sdk"
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, TestConstants.sdkVersion)
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

        XCTAssertEqual(try XCTUnwrap(crashReporter.ksCrash?.userInfo["some"]) as? String, "value")
    }

    func test_appendCrashInfo_addsDefaultInfoWhenBeingCalled() throws {
        givenCrashReporter()

        crashReporter.appendCrashInfo(key: "some", value: "value")

        let ksCrash = try XCTUnwrap(crashReporter.ksCrash)
        for expectedKey in [ "emb-sdk", "emb-sid" ] {
            XCTAssertTrue(ksCrash.userInfo.keys.contains(AnyHashable(expectedKey)))
        }
    }

    func testInKSCrash_appendCrashInfo_shouldntDeletePreexistingKeys() throws {
        givenCrashReporter()
        crashReporter.ksCrash?.userInfo = ["initial_key": "one_value"]

        crashReporter.appendCrashInfo(key: "some", value: "value")

        let ksCrash = try XCTUnwrap(crashReporter.ksCrash)
        for expectedKey in [ "emb-sdk", "emb-sid" ] {
            XCTAssertTrue(ksCrash.userInfo.keys.contains(AnyHashable(expectedKey)))
        }
        XCTAssertEqual(ksCrash.userInfo["initial_key"] as? String, "one_value")
    }

    func testHavingInternalAddedInfoInKSCrash_appendCrashInfo_shouldntEraseThoseValues() throws {
        // given crash reporter with an already set sdkVersion and sessionId
        crashReporter = EmbraceCrashReporter(queue: MockQueue())
        let context = CrashReporterContext(
            appId: "_-_-_",
            sdkVersion: "1.2.3",
            filePathProvider: TemporaryFilepathProvider(),
            notificationCenter: .default
        )
        crashReporter.install(context: context, logger: logger)
        crashReporter.currentSessionId = "original_session_id"
        let ksCrash = try XCTUnwrap(crashReporter.ksCrash)

        // [Intermediate Assertion to ensure the `given` state]
        XCTAssertEqual(ksCrash.userInfo["emb-sid"] as? String, "original_session_id")
        XCTAssertEqual(ksCrash.userInfo["emb-sdk"] as? String, "1.2.3")

        // When trying to change the internal (necessary) properties from kscrash
        crashReporter.appendCrashInfo(key: "emb-sid", value: "maliciously_updated_session_id")
        crashReporter.appendCrashInfo(key: "emb-sdk", value: "1.2.3-broken")

        // Then values should remain untouched
        XCTAssertEqual(ksCrash.userInfo["emb-sid"] as? String, "original_session_id")
        XCTAssertEqual(ksCrash.userInfo["emb-sdk"] as? String, "1.2.3")
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
        crashReporter = EmbraceCrashReporter(queue: MockQueue(), signalsBlockList: [])
        crashReporter.install(context: context, logger: logger)

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
        crashReporter = EmbraceCrashReporter(queue: MockQueue(), signalsBlockList: [.SIGABRT])
        crashReporter.install(context: context, logger: logger)

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

private extension EmbraceCrashReporterTests {
    func copyReport(named: String, toFilePath: String) throws {
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

    func thenShouldntExistReport(withName name: String) {
        do {
            let basePath = try XCTUnwrap(crashReporter.basePath)
            XCTAssertFalse(FileManager.default.fileExists(atPath: basePath + "/Reports/" + name))
        } catch let ex {
            XCTFail(ex.localizedDescription)
        }
    }

    func givenCrashReporter() {
        crashReporter = EmbraceCrashReporter(queue: MockQueue())
        crashReporter.install(context: context, logger: logger)
    }
}
