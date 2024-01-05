//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommon

@testable import EmbraceCore

final class EmbraceSetupCaptureServicesTests: XCTestCase {

    class ExampleCaptureService: CaptureService {

        var didStart = false
        var didStop = false
        var available = true

        func setup(context: EmbraceCommon.CaptureServiceContext) { }

        func start() {
            didStart = true
        }

        func stop() {
            didStop = true
        }
    }

    class ExampleInstalledCaptureService: InstalledCaptureService {
        var didStart = false
        var didStop = false
        var available = true

        var didInstall = false
        var didShutdown = false

        func start() {
            didStart = true
        }

        func stop() {
            didStop = true
        }

        func install(context: EmbraceCommon.CaptureServiceContext) {
            didInstall = true
        }

        func uninstall() {
            didShutdown = true
        }
    }

    class ExampleCrashReporter: CrashReporter {
        var currentSessionId: EmbraceCommon.SessionIdentifier?
        func getLastRunState() -> EmbraceCommon.LastRunState { .cleanExit }
        func fetchUnsentCrashReports(completion: @escaping ([EmbraceCommon.CrashReport]) -> Void) {}
        func deleteCrashReport(id: Int) {}
        func install(context: EmbraceCommon.CaptureServiceContext) {}
        func uninstall() {}
        func start() {}
        func stop() {}
    }
    
    class SecondExampleCrashReporter: CrashReporter {
        var currentSessionId: EmbraceCommon.SessionIdentifier?
        func getLastRunState() -> EmbraceCommon.LastRunState { .cleanExit }
        func fetchUnsentCrashReports(completion: @escaping ([EmbraceCommon.CrashReport]) -> Void) {}
        func deleteCrashReport(id: Int) {}
        func install(context: EmbraceCommon.CaptureServiceContext) {}
        func uninstall() {}
        func start() {}
        func stop() {}
    }

    override func tearDown() {
        Embrace.client = nil
    }

    func test_EmbraceSetup_passesCaptureServices() throws {
        try Embrace.setup(options: .init(appId: "myAPP", captureServices: [
            ExampleCaptureService(),
            ExampleInstalledCaptureService(),
            ExampleCrashReporter()
        ]))

        let services = Embrace.client!.captureServices.services
        XCTAssertTrue(services.contains { $0 is ExampleCaptureService })
        XCTAssertTrue(services.contains { $0 is ExampleInstalledCaptureService })
        XCTAssertTrue(services.contains { $0 is ExampleCrashReporter })
    }

    func test_onlyOneCrashReporterCaptureServiceIsAllowed() throws {
        XCTAssertThrowsError(try Embrace.setup(options: .init(appId: "myAPP", captureServices: [
            ExampleCaptureService(),
            ExampleInstalledCaptureService(),
            ExampleCrashReporter(),
            SecondExampleCrashReporter()
        ])))
    }
}
