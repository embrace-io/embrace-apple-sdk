//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCore
import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceOTelInternal
import TestSupport

final class Embrace_OptionsTests: XCTestCase {

    func test_init_withAppId_setsAppId_andNotExport() throws {
        let options = Embrace.Options(appId: "myApp", captureServices: [], crashReporter: nil)
        XCTAssertEqual(options.appId, "myApp")
        XCTAssertNil(options.export)
    }

    func test_init_withEndpoints_setsEndpoints() throws {
        let endpoints = Embrace.Endpoints(baseURL: "base", configBaseURL: "config")
        let options = Embrace.Options(appId: "myApp", endpoints: endpoints, captureServices: [], crashReporter: nil)
        XCTAssertEqual(options.endpoints, endpoints)
    }

    func test_init_withExport_setsExport_andNotAppId() throws {
        let export = OpenTelemetryExport()
        let options = Embrace.Options(export: export, captureServices: [], crashReporter: nil)
        XCTAssertEqual(options.export, export)
        XCTAssertNil(options.appId)
    }
    
    func test_init_withProcessors() throws {
        let processor = OpenTelemetryProcessor(processor: InMemorySpanProcessor())
        let options = Embrace.Options(
            appId: "myApp",
            captureServices: [],
            crashReporter: nil,
            processors: [processor]
        )
        XCTAssertEqual(options.processors, [processor])
        XCTAssertNotNil(options.appId)
    }
    
    func test_init_withRuntimeConfiguration_usesInjectedObject() throws {
        let mockObj = MockEmbraceConfigurable()

        let options = Embrace.Options(
            export: OpenTelemetryExport(),
            captureServices: [],
            crashReporter: nil,
            runtimeConfiguration: mockObj
        )

        XCTAssertTrue(mockObj === options.runtimeConfiguration)
    }
}
