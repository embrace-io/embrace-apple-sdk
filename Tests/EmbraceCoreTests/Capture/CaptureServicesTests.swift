//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class CaptureServicesTests: XCTestCase {

    let context = CrashReporterContext(
        appId: TestConstants.appId,
        sdkVersion: TestConstants.sdkVersion,
        filePathProvider: TemporaryFilepathProvider(),
        notificationCenter: NotificationCenter.default
    )

    private func captureServices(crashReporter: CrashReporter?) -> CaptureServices {
        let services = CaptureServices(config: nil, services: [], context: context)
        if let crashReporter {
            services.crashReporter = EmbraceCrashReporter(reporter: crashReporter)
        }
        return services
    }

    func test_addMetricKitServices_noCrashReporter() {
        // given capture services without a crash reporter
        let services = captureServices(crashReporter: nil)

        // when adding the MetricKit services
        services.addMetricKitServices(payloadProvider: nil, metadataFetcher: nil, stateProvider: nil)

        // then the MetricKit services are added
        XCTAssertEqual(services.services.count, 3)
        XCTAssert(services.services.contains { $0 is MetricKitCrashCaptureService })
        XCTAssert(services.services.contains { $0 is MetricKitHangCaptureService })
        XCTAssert(services.services.contains { $0 is MetricKitMetricsCaptureService })
    }

    func test_addMetricKitServices_crashReporterAllowsMetricKit() {
        // given a crash reporter that doesn't disable MetricKit reports
        let reporter = CrashReporterMock()
        reporter.disableMetricKitReports = false
        let services = captureServices(crashReporter: reporter)

        // when adding the MetricKit services
        services.addMetricKitServices(payloadProvider: nil, metadataFetcher: nil, stateProvider: nil)

        // then the MetricKit services are added
        XCTAssertEqual(services.services.count, 3)
        XCTAssert(services.services.contains { $0 is MetricKitCrashCaptureService })
        XCTAssert(services.services.contains { $0 is MetricKitHangCaptureService })
        XCTAssert(services.services.contains { $0 is MetricKitMetricsCaptureService })
    }

    func test_addMetricKitServices_crashReporterDisablesMetricKit() {
        // given a crash reporter that disables MetricKit reports
        let reporter = CrashReporterMock()
        reporter.disableMetricKitReports = true
        let services = captureServices(crashReporter: reporter)

        // when adding the MetricKit services
        services.addMetricKitServices(payloadProvider: nil, metadataFetcher: nil, stateProvider: nil)

        // then no MetricKit service is added
        XCTAssert(services.services.isEmpty)
    }

    // MARK: Adding capture services

    func test_add_appendsService() {
        // given capture services
        let services = captureServices(crashReporter: nil)

        // when adding a capture service
        let service = LateCaptureService()
        let result = services.add(service)

        // then the service is added but not installed
        XCTAssertTrue(result)
        XCTAssertTrue(services.services.contains { $0 === service })
        XCTAssertTrue(service.isUninstalled)
    }

    func test_add_rejectsDuplicateType() {
        // given capture services with a capture service already added
        let services = captureServices(crashReporter: nil)
        services.add(LateCaptureService())

        // when adding another capture service of the same type
        let result = services.add(LateCaptureService())

        // then it's rejected
        XCTAssertFalse(result)
        XCTAssertEqual(services.services.count, 1)
    }
}

class LateCaptureService: CaptureService {
    var installCount = 0
    var startCount = 0
    var sessionStartCount = 0

    override func onInstall() { installCount += 1 }
    override func onStart() { startCount += 1 }
    override func onSessionStart() { sessionStartCount += 1 }
}
