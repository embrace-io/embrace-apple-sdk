//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceCrash

class EmbraceUploadCacheOptionsTests: XCTestCase {

    var path: String {
        let path = NSSearchPathForDirectoriesInDomains(
            FileManager.SearchPathDirectory.cachesDirectory,
            FileManager.SearchPathDomainMask.userDomainMask,
            true
        ).first!
        return path + "/crashes_test/"
    }

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    override func tearDownWithError() throws {

    }

    func test_currentSessionId() {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.configure(appId: TestConstants.appId, path: path)
        crashReporter.install()

        // when setting the current session id
        crashReporter.currentSessionId = "test"

        // then KSCrash's user info is properly set
        let key = EmbraceCrashReporter.UserInfoKey.sessionId.rawValue
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, "test")
    }

    func test_sdkVersion() {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.configure(appId: TestConstants.appId, path: path)
        crashReporter.install()

        // when setting the current session id
        crashReporter.sdkVersion = "test"

        // then KSCrash's user info is properly set
        let key = EmbraceCrashReporter.UserInfoKey.sdkVersion.rawValue
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, "test")
    }

    func test_appVersion() {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.configure(appId: TestConstants.appId, path: path)
        crashReporter.install()

        // when setting the current session id
        crashReporter.appVersion = "test"

        // then KSCrash's user info is properly set
        let key = EmbraceCrashReporter.UserInfoKey.appVersion.rawValue
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, "test")
    }

    func test_fetchCrashReports() throws {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.configure(appId: TestConstants.appId, path: path)
        crashReporter.install()
        crashReporter.start()

        // given some fake crash report
        try FileManager.default.createDirectory(atPath: path + "Reports/", withIntermediateDirectories: true)
        let report = Bundle.module.path(forResource: "report", ofType: "json")!
        let finalPath = path + "Reports/appId-report-0000000000000001.json"
        try FileManager.default.copyItem(atPath: report, toPath: finalPath)

        // then the report is fetched
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 1)
            XCTAssertEqual(reports[0].sessionId, "18EDB6CE-90C2-456B-97CB-91E0F5941CCA")
            XCTAssertEqual(reports[0].sdkVersion, "6.0.0")
            XCTAssertEqual(reports[0].appVersion, "1.0.0")
            XCTAssertNotNil(reports[0].timestamp)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func test_fetchCrashReports_count() throws {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.configure(appId: TestConstants.appId, path: path)
        crashReporter.install()
        crashReporter.start()

        // given some fake crash report
        try FileManager.default.createDirectory(atPath: path + "Reports/", withIntermediateDirectories: true)
        let report = Bundle.module.path(forResource: "report", ofType: "json")!

        for i in 1...9 {
            let finalPath = path + "Reports/appId-report-000000000000000\(i).json"
            try FileManager.default.copyItem(atPath: report, toPath: finalPath)
        }

        // then the report is fetched
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 9)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }
}
