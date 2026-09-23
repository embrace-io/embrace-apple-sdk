//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

// on watchOS, KSCrash only supports exception..
// Due to this, there's no crash support on watchOS.
#if !os(watchOS)

    import EmbraceCommonInternal
    import TestSupport
    import XCTest
    import EmbraceSemantics

    @testable import EmbraceCore
    @testable import EmbraceCrash

    class EmbraceCrashReporterTests: XCTestCase {

        let logger = MockLogger()
        var context: CrashReporterContext = .testContext
        var crashReporter: EmbraceCrashReporter!

        override func setUpWithError() throws {
            try? FileManager.default.removeItem(
                at: context.filePathProvider.directoryURL(for: "embrace_crash_reporter")!)
        }

        override func tearDownWithError() throws {
            try? FileManager.default.removeItem(
                at: context.filePathProvider.directoryURL(for: "embrace_crash_reporter")!)
        }

        func test_currentSessionId() {
            givenCrashReporter()

            // when setting the current session id
            let sessionId = EmbraceIdentifier.random
            crashReporter.currentSessionId = sessionId.stringValue

            // then KSCrash's user info is properly set
            XCTAssertEqual(crashReporter.getCrashInfo(key: CrashReporterInfoKey.sessionId), sessionId.stringValue)
        }

        func test_currentUserSessionId_writesEmbUsi() {
            givenCrashReporter()

            let userSessionId = EmbraceIdentifier.random
            crashReporter.currentUserSessionId = userSessionId.stringValue

            XCTAssertEqual(
                crashReporter.getCrashInfo(key: CrashReporterInfoKey.userSessionId),
                userSessionId.stringValue
            )
            XCTAssertEqual(crashReporter.currentUserSessionId, userSessionId.stringValue)
        }

        func test_currentUserSessionId_clearsWhenSetToNil() {
            givenCrashReporter()

            crashReporter.currentUserSessionId = "U1"
            XCTAssertEqual(crashReporter.currentUserSessionId, "U1")

            crashReporter.currentUserSessionId = nil
            XCTAssertNil(crashReporter.currentUserSessionId)
        }

        func test_currentUserSessionId_cannotBeOverriddenByPlainAppendCrashInfo() {
            givenCrashReporter()

            crashReporter.currentUserSessionId = "real-user-session"
            // External callers cannot overwrite the internal keys via the generic API.
            crashReporter.appendCrashInfo(key: CrashReporterInfoKey.userSessionId, value: "spoofed")

            XCTAssertEqual(crashReporter.currentUserSessionId, "real-user-session")
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
            let reports = fetchUnsentCrashReports()
            XCTAssertEqual(reports.count, 1)
            let report = try XCTUnwrap(reports.first)
            XCTAssertEqual(report.sessionId, TestConstants.sessionId.stringValue)
            XCTAssertNotNil(report.timestamp)
        }

        func test_fetchCrashReports_count() throws {
            givenCrashReporter()

            // given some fake crash report
            for i in 1...9 {
                try copyReport(named: "crash_report", toFilePath: "/Reports/appId-report-000000000000000\(i).json")
            }

            // then the report is fetched
            XCTAssertEqual(fetchUnsentCrashReports().count, 9)
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

            // when fetching unsent crash reports
            let reports = fetchUnsentCrashReports()

            // Then only one report should be present
            XCTAssertEqual(reports.count, 1)
            // and report shouldn't be the one with the SIGTERM signal
            XCTAssertEqual(try XCTUnwrap(reports.first).internalId, 1)
            // and dropped report should have been deleted
            thenShouldntExistReport(withName: "appId-report-0000000000000002.json")
        }

        func testOnHavingEmptySignalBlockList_fetchUnsentCrashReports_SIGTERMshouldBeReported() throws {
            // given a crash reporter with no blocklist
            crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), signalsBlockList: [])
            crashReporter.install(context: context)

            // given some fake crash reports (SIGABRT + SIGTERM)
            try copyReport(named: "sigabrt_report", toFilePath: "/Reports/appId-report-0000000000000001.json")
            try copyReport(named: "sigterm_report", toFilePath: "/Reports/appId-report-0000000000000002.json")

            // when fetching unsent crash reports
            let reports = fetchUnsentCrashReports()

            // Then both reports should be present
            XCTAssertEqual(reports.map(\.internalId), [1, 2])
        }

        func testOnModifyingSignalBlockList_fetchUnsentCrashReports_shouldAvoidReportingBlockedSignals() throws {
            // given a crash reporter preventing SIGABRT from being reported
            crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), signalsBlockList: [.SIGABRT])
            crashReporter.install(context: context)

            // given some fake crash reports (nonBlocked SIGTERM + blocked SIGABRT)
            try copyReport(named: "sigabrt_report", toFilePath: "/Reports/appId-report-0000000000000001.json")
            try copyReport(named: "sigterm_report", toFilePath: "/Reports/appId-report-0000000000000002.json")

            // when fetching unsent crash reports
            let reports = fetchUnsentCrashReports()

            // Then only one report should be
            XCTAssertEqual(reports.count, 1)
            // and report shouldn't be the one with the SIGABRT signal
            XCTAssertEqual(try XCTUnwrap(reports.first).internalId, 2)
            // and dropped report should have been deleted
            thenShouldntExistReport(withName: "appId-report-0000000000000001.json")
        }

        // MARK: - Injected Termination Report Tests

        // KSCrash 2.6.0's `termination` monitor injects a report at launch for every
        // termination reason it infers. Its 2.5.1 predecessor only reported OOMs the user
        // could have perceived, so only those may reach the crash pipeline.

        func testOnInjectedTerminationReport_fetchUnsentCrashReports_userPerceptibleOOMshouldBeReported() throws {
            givenCrashReporter()

            try copyReport(
                named: "termination_oom_foreground_report",
                toFilePath: "/Reports/appId-report-0000000000000001.json"
            )

            let reports = fetchUnsentCrashReports()
            XCTAssertEqual(reports.count, 1)
            let report = try XCTUnwrap(reports.first)
            XCTAssertEqual(report.internalId, 1)
            // KSCrash fabricates a SIGKILL for these, matching what 2.5.1 stamped on a
            // promoted OOM breadcrumb, so the default block list must not catch it.
            XCTAssertEqual(report.signal, .SIGKILL)
            XCTAssertNotNil(report.timestamp)
            // Known gap versus 2.5.1: KSCrash hand-builds these reports with no `user`
            // section, so there is no session to attribute them to.
            XCTAssertNil(report.sessionId)
        }

        func testOnInjectedTerminationReport_fetchUnsentCrashReports_backgroundOOMshouldntBeReported() throws {
            givenCrashReporter()

            try copyReport(
                named: "termination_oom_background_report",
                toFilePath: "/Reports/appId-report-0000000000000001.json"
            )

            XCTAssertEqual(fetchUnsentCrashReports().count, 0)
            thenShouldntExistReport(withName: "appId-report-0000000000000001.json")
        }

        func testOnInjectedTerminationReport_fetchUnsentCrashReports_unexplainedShouldntBeReported() throws {
            givenCrashReporter()

            try copyReport(
                named: "termination_unexplained_report",
                toFilePath: "/Reports/appId-report-0000000000000001.json"
            )

            // A plain force-quit lands in `unexplained`; reporting it would turn every
            // swipe-away in the app switcher into a crash.
            XCTAssertEqual(fetchUnsentCrashReports().count, 0)
            thenShouldntExistReport(withName: "appId-report-0000000000000001.json")
        }

        func testOnInjectedTerminationReports_fetchUnsentCrashReports_shouldntAffectRealCrashes() throws {
            givenCrashReporter()

            // given a real crash report alongside two droppable injected termination reports
            try copyReport(named: "crash_report", toFilePath: "/Reports/appId-report-0000000000000001.json")
            try copyReport(
                named: "termination_unexplained_report",
                toFilePath: "/Reports/appId-report-0000000000000002.json"
            )
            try copyReport(
                named: "termination_oom_background_report",
                toFilePath: "/Reports/appId-report-0000000000000003.json"
            )

            let reports = fetchUnsentCrashReports()
            XCTAssertEqual(reports.count, 1)
            let report = try XCTUnwrap(reports.first)
            XCTAssertEqual(report.internalId, 1)
            XCTAssertEqual(report.sessionId, TestConstants.sessionId.stringValue)
            thenShouldntExistReport(withName: "appId-report-0000000000000002.json")
            thenShouldntExistReport(withName: "appId-report-0000000000000003.json")
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

        /// Fetches the unsent reports and returns them once the fetch has completed.
        ///
        /// `fetchUnsentCrashReports` runs on the reporter's serial queue and calls its completion
        /// before that block returns, so an empty `sync` on the same queue waits for the result.
        fileprivate func fetchUnsentCrashReports() -> [EmbraceCrashReport] {
            var fetched: [EmbraceCrashReport] = []
            crashReporter.fetchUnsentCrashReports { reports in
                fetched = reports
            }
            crashReporter.queue.sync {}
            return fetched
        }

        fileprivate func givenCrashReporter() {
            crashReporter = EmbraceCrashReporter(reporter: KSCrashReporter(), logger: logger)
            crashReporter.currentSessionId = UUID().uuidString
            crashReporter.install(context: context)
        }
    }

#endif
