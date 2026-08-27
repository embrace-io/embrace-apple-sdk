//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceIO

class EmbraceIOOptionsTests: XCTestCase {

    func test_withAppId_derivesEndpointsFromAppId_andNilsRuntimeConfiguration() {
        let options = EmbraceIO.Options.withAppId("myApp")

        XCTAssertEqual(options.appId, "myApp")

        // endpoints default to the Embrace endpoints derived from the appId
        let expected = EmbraceEndpoints(appId: "myApp")
        XCTAssertEqual(options.endpoints?.baseURL, expected.baseURL)
        XCTAssertEqual(options.endpoints?.configBaseURL, expected.configBaseURL)

        // the appId mode never carries a local runtime configuration
        XCTAssertNil(options.runtimeConfiguration)
    }

    func test_withAppId_honorsExplicitEndpoints() {
        let custom = EmbraceEndpoints(baseURL: "base", configBaseURL: "config")
        let options = EmbraceIO.Options.withAppId("myApp", endpoints: custom)

        XCTAssertEqual(options.endpoints?.baseURL, "base")
        XCTAssertEqual(options.endpoints?.configBaseURL, "config")
    }

    func test_withLocalConfiguration_keepsConfig_andHasNilAppIdAndEndpoints() throws {
        let config = MockEmbraceConfigurable()
        let options = EmbraceIO.Options.withLocalConfiguration(config, otel: EmbraceIO.OTelOptions())

        // local-config mode has no appId, so no derived endpoints either
        XCTAssertNil(options.appId)
        XCTAssertNil(options.endpoints)

        // and the provided configuration is retained
        let stored = try XCTUnwrap(options.runtimeConfiguration as? MockEmbraceConfigurable)
        XCTAssertTrue(stored === config)
    }
}
