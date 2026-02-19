//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
import XCTest

@testable import EmbraceIO

final class EmbraceDefaultResourcesTests: XCTestCase {

    // MARK: - Defaults (no user resource)

    func test_build_includesServiceName() {
        let resource = EmbraceDefaultResources.build()
        let expected = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
            .compactMap { $0 }
            .joined(separator: ":")
        XCTAssertEqual(resource.attributes["service.name"], .string(expected))
    }

    func test_build_includesSdkLanguage() {
        let resource = EmbraceDefaultResources.build()
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }

    func test_build_includesServiceVersion_whenAvailable() {
        // service.version is only set when CFBundleShortVersionString is present in the bundle.
        // In a test environment it may not be, so we verify the value matches the bundle if present.
        let resource = EmbraceDefaultResources.build()
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            XCTAssertEqual(resource.attributes["service.version"], .string(version))
        } else {
            XCTAssertNil(resource.attributes["service.version"])
        }
    }

    // MARK: - User resource overrides defaults

    func test_build_userServiceName_overridesDefault() {
        let userResource = Resource(attributes: ["service.name": .string("my-custom-app")])
        let resource = EmbraceDefaultResources.build(merging: userResource)
        XCTAssertEqual(resource.attributes["service.name"], .string("my-custom-app"))
    }

    func test_build_userSdkLanguage_overridesDefault() {
        let userResource = Resource(attributes: ["telemetry.sdk.language": .string("objective-c")])
        let resource = EmbraceDefaultResources.build(merging: userResource)
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("objective-c"))
    }

    // MARK: - Partial override: missing user keys still get defaults

    func test_build_userOverridesServiceName_defaultSdkLanguageStillPresent() {
        let userResource = Resource(attributes: ["service.name": .string("custom")])
        let resource = EmbraceDefaultResources.build(merging: userResource)
        XCTAssertEqual(resource.attributes["service.name"], .string("custom"))
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }

    func test_build_userAddsNewKey_defaultsStillPresent() {
        let userResource = Resource(attributes: ["my.custom.key": .string("custom-value")])
        let resource = EmbraceDefaultResources.build(merging: userResource)
        XCTAssertEqual(resource.attributes["my.custom.key"], .string("custom-value"))
        // Defaults are still present
        let expectedServiceName = [Bundle.main.bundleIdentifier, ProcessInfo.processInfo.processName]
            .compactMap { $0 }
            .joined(separator: ":")
        XCTAssertEqual(resource.attributes["service.name"], .string(expectedServiceName))
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }

    // MARK: - Nil user resource

    func test_build_nilUserResource_returnsDefaults() {
        let resource = EmbraceDefaultResources.build(merging: nil)
        XCTAssertNotNil(resource.attributes["service.name"])
        XCTAssertEqual(resource.attributes["telemetry.sdk.language"], .string("swift"))
    }
}
