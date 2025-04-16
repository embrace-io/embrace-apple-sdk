//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCaptureService
import EmbraceCommonInternal

@testable import EmbraceCore

final class EmbraceSetupCaptureServicesTests: XCTestCase {

    class ExampleCaptureService: CaptureService {
    }

    class ExampleCrashReporter: CrashReporter {
        var currentSessionId: String?
        func install(context: CrashReporterContext, logger: InternalLogger) { }
        func getLastRunState() -> LastRunState { return .cleanExit }
        func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) { }
        var onNewReport: ((EmbraceCrashReport) -> Void)?
        func deleteCrashReport(id: Int) { }
    }

    override func tearDown() {
        Embrace.client = nil
    }

    func test_setup() throws {
        let options = Embrace.Options(
            appId: "myAPP",
            captureServices: [ ExampleCaptureService() ],
            crashReporter: ExampleCrashReporter()
        )
        try Embrace.setup(options: options)

        let services = Embrace.client!.captureServices.services
        XCTAssertTrue(services.contains { $0 is ExampleCaptureService })

        let crashReporter = Embrace.client!.captureServices.crashReporter
        XCTAssertNotNil(crashReporter)
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
