//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCrashlyticsSupport
import EmbraceCommon
import TestSupport
import XCTest

class CrashlyticsReporterTests: XCTestCase {

    func test_crashReportGeneration() throws {
        // given a crashlytics reporter
        let options = CrashlyticsReporter.Options(domain: "test.com", path: "path")
        let reporter = CrashlyticsReporter(options: options)

        // given its installed correctly
        let context = CrashReporterContext(
            appId: TestConstants.appId,
            sdkVersion: TestConstants.sdkVersion,
            filePathProvider: TemporaryFilepathProvider(),
            notificationCenter: NotificationCenter.default
        )
        reporter.install(context: context)

        let expectation = XCTestExpectation()
        reporter.onNewReport = { _ in
            expectation.fulfill()
        }

        // when a network request is captured with the right url
        var request = URLRequest(url: URL(string: "https://www.test.com/path")!)
        request.httpBody = TestConstants.data
        let task = URLSession.shared.dataTask(with: request)
        NotificationCenter.default.post(name: Notification.Name("networkRequestCaptured"), object: task)

        // then a report is generated
        wait(for: [expectation], timeout: .veryLongTimeout)
    }

    func test_wrongURL() throws {
        // given a crashlytics reporter
        let options = CrashlyticsReporter.Options(domain: "test.com", path: "path")
        let reporter = CrashlyticsReporter(options: options)

        // given its installed correctly
        let context = CrashReporterContext(
            appId: TestConstants.appId,
            sdkVersion: TestConstants.sdkVersion,
            filePathProvider: TemporaryFilepathProvider(),
            notificationCenter: NotificationCenter.default
        )
        reporter.install(context: context)

        let expectation = XCTestExpectation()
        expectation.isInverted = true
        reporter.onNewReport = { _ in
            expectation.fulfill()
        }

        // when a network request is captured with the wrong url
        var request = URLRequest(url: URL(string: "https://www.wrongDomain.com/path")!)
        request.httpBody = TestConstants.data
        let task = URLSession.shared.dataTask(with: request)
        NotificationCenter.default.post(name: Notification.Name("networkRequestCaptured"), object: task)

        // then a report is not generated
        wait(for: [expectation], timeout: .veryLongTimeout)
    }
}
