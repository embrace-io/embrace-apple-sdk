//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import XCTest

@testable import EmbraceCore

@MainActor
final class EmbraceSetupCaptureServicesTests: XCTestCase {

    class ExampleCaptureService: CaptureService {
    }

    class ExampleCrashReporter: CrashReporter {
        var sdkVersion: String?
        func appendCrashInfo(key: String, value: String?) {}
        func getCrashInfo(key: String) -> String? { nil }
        var basePath: String? = nil
        var currentSessionId: String?
        func install(context: CrashReporterContext) throws {}
        func getLastRunState() -> LastRunState { return .cleanExit }
        func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {}
        var onNewReport: ((EmbraceCrashReport) -> Void)?
        func deleteCrashReport(_ report: EmbraceCrashReport) {}
        var disableMetricKitReports: Bool = true
    }

    override func tearDown() {
        Embrace.client = nil
    }

    func test_setup() throws {
        let options = Embrace.Options(
            appId: "myAPP",
            captureServices: [ExampleCaptureService()],
            crashReporter: ExampleCrashReporter()
        )
        try Embrace.setup(options: options)

        let services = Embrace.client!.captureServices.services
        XCTAssertTrue(services.contains { $0 is ExampleCaptureService })

        let crashReporter = Embrace.client!.captureServices.crashReporter
        XCTAssertNotNil(crashReporter)
    }

    func test_setup_include_metrickit() throws {
        let crashReporter = ExampleCrashReporter()
        crashReporter.disableMetricKitReports = false

        let options = Embrace.Options(
            appId: "myAPP",
            captureServices: [ExampleCaptureService()],
            crashReporter: crashReporter
        )
        try Embrace.setup(options: options)

        let services = Embrace.client!.captureServices.services
        XCTAssertEqual(services.count, 6)
        XCTAssertTrue(services.contains { $0 is ExampleCaptureService })
        XCTAssertTrue(services.contains { $0 is MetricKitCrashCaptureService })
        XCTAssertTrue(services.contains { $0 is MetricKitHangCaptureService })
        XCTAssertTrue(services.contains { $0 is MetricKitMetricsCaptureService })
    }

    func test_setup_do_not_include_metrickit() throws {
        let crashReporter = ExampleCrashReporter()
        crashReporter.disableMetricKitReports = true

        let options = Embrace.Options(
            appId: "myAPP",
            captureServices: [ExampleCaptureService()],
            crashReporter: crashReporter
        )
        try Embrace.setup(options: options)

        let services = Embrace.client!.captureServices.services
        XCTAssertEqual(services.count, 3)
        XCTAssertTrue(services.contains { $0 is ExampleCaptureService })
        XCTAssertFalse(services.contains { $0 is MetricKitCrashCaptureService })
    }

    func test_duplicatedServices() throws {
        let options = Embrace.Options(
            appId: "myAPP",
            captureServices: [
                ExampleCaptureService(),
                ExampleCaptureService(),
                ExampleCaptureService()
            ],
            crashReporter: nil
        )
        try Embrace.setup(options: options)

        let services = Embrace.client!.captureServices.services
        XCTAssertEqual(services.filter { $0 is ExampleCaptureService }.count, 1)

        let crashReporter = Embrace.client!.captureServices.crashReporter
        XCTAssertNil(crashReporter)
    }
}
