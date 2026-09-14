//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

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
}
