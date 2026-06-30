//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfigInternal
import EmbraceConfiguration
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

final class Embrace_OptionsTests: XCTestCase {

    func test_init_withAppId_setsAppId() throws {
        let options = Embrace.Options(appId: "myApp", captureServices: [], crashReporter: nil)
        XCTAssertEqual(options.appId, "myApp")
    }

    func test_init_withEndpoints_setsEndpoints() throws {
        let endpoints = EmbraceEndpoints(baseURL: "base", configBaseURL: "config")
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

    func test_validate_validAppId_doesNotThrow() throws {
        // "myApp" is exactly 5 characters
        let options = Embrace.Options(appId: "myApp", captureServices: [], crashReporter: nil)
        XCTAssertNoThrow(try options.validate())
    }

    func test_validate_appIdWrongLength_throwsInvalidAppId() throws {
        let options = Embrace.Options(appId: "abc", captureServices: [], crashReporter: nil)
        XCTAssertThrowsError(try options.validate()) { error in
            guard let setupError = error as? EmbraceSetupError, case .invalidAppId = setupError else {
                return XCTFail("expected EmbraceSetupError.invalidAppId, got \(error)")
            }
        }
    }

    func test_validate_emptyAppGroupId_throwsInvalidAppGroupId() throws {
        let options = Embrace.Options(appId: "myApp", appGroupId: "", captureServices: [], crashReporter: nil)
        XCTAssertThrowsError(try options.validate()) { error in
            guard let setupError = error as? EmbraceSetupError, case .invalidAppGroupId = setupError else {
                return XCTFail("expected EmbraceSetupError.invalidAppGroupId, got \(error)")
            }
        }
    }

    func test_validate_nilAppId_doesNotThrow() throws {
        // the local-configuration initializer leaves appId nil, which is valid
        let options = Embrace.Options(
            captureServices: [],
            crashReporter: nil,
            runtimeConfiguration: MockEmbraceConfigurable()
        )
        XCTAssertNoThrow(try options.validate())
    }
}
