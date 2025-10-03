//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceCore
import TestSupport
import XCTest

final class Embrace_OptionsTests: XCTestCase {

    func test_init_withAppId_setsAppId() throws {
        let options = Embrace.Options(appId: "myApp", captureServices: [], crashReporter: nil)
        XCTAssertEqual(options.appId, "myApp")
    }

    func test_init_withEndpoints_setsEndpoints() throws {
        let endpoints = Embrace.Endpoints(baseURL: "base", configBaseURL: "config")
        let options = Embrace.Options(appId: "myApp", endpoints: endpoints, captureServices: [], crashReporter: nil)

        XCTAssertEqual(options.endpoints?.baseURL, endpoints.baseURL)
        XCTAssertEqual(options.endpoints?.configBaseURL, endpoints.configBaseURL)
    }

    func test_init_withRuntimeConfiguration_usesInjectedObject() throws {
        let mockObj = MockEmbraceConfigurable()

        let options = Embrace.Options(
            captureServices: [],
            crashReporter: nil,
            runtimeConfiguration: mockObj
        )

        XCTAssertTrue(mockObj === options.runtimeConfiguration)
    }
}
