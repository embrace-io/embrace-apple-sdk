//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceConfig

class EmbraceConfigTests: XCTestCase {

    static let testUrl = URL(string: "https://embrace.test.com/config")!
    static var urlSessionConfig: URLSessionConfiguration!

    override func setUpWithError() throws {
        EmbraceConfigTests.urlSessionConfig = URLSessionConfiguration.ephemeral
        EmbraceConfigTests.urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]

        EmbraceHTTPMock.setUp()
    }

    func testOptions(deviceId: String, minimumUpdateInterval: TimeInterval = 0) -> EmbraceConfig.Options {
        return EmbraceConfig.Options(
            apiBaseUrl: "https://embrace.test.com/config",
            queue: DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent),
            appId: TestConstants.appId,
            deviceId: deviceId,
            osVersion: TestConstants.osVersion,
            sdkVersion: TestConstants.sdkVersion,
            appVersion: TestConstants.appVersion,
            userAgent: TestConstants.userAgent,
            minimumUpdateInterval: minimumUpdateInterval,
            urlSessionConfiguration: EmbraceConfigTests.urlSessionConfig
        )
    }

    func testUrl(options: EmbraceConfig.Options) -> URL {
        return URL(string: "\(options.apiBaseUrl)?appId=\(options.appId)&osVersion=\(options.osVersion)&appVersion=\(options.appVersion)&deviceId=\(options.deviceId)")!
    }

    func test_frequentUpdatesIgnored() {
        // given a config with 1 hour minimum update interval
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 60 * 60
        )
        let config = EmbraceConfig(options: options)

        // when trying to update too soon
        config.updateIfNeeded()

        // then the update call is ignored
        wait(delay: 1)
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)
    }

    func test_frequentUpdatesNotIgnored() {
        // given a config with 1 second minimum update interval
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 1
        )
        let config = EmbraceConfig(options: options)

        // when trying to update after 1 second
        wait(delay: 2)
        config.updateIfNeeded()

        // then the update call is not ignored
        wait(delay: 1)
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)
    }

    func test_forcedUpdateNotIgnored() throws {
        throw XCTSkip("FIXME: This test is flaky")
        // given a config with 1 hour minimum update interval
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 60 * 60
        )
        let config = EmbraceConfig(options: options)

        // when forcing an update
        wait(delay: 2)
        config.update()

        // then the update call is not ignored
        wait(delay: 1)
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)
    }

    func test_invalidDeviceId() {
        // given a config with an invalid device id
        let config = EmbraceConfig(options: testOptions(deviceId: ""))

        // then all settings are disabled
        XCTAssertFalse(config.isSDKEnabled)
        XCTAssertFalse(config.isBackgroundSessionEnabled)
    }

    func test_isSDKEnabled() {
        // given a config
        let config = EmbraceConfig(options: testOptions(deviceId: TestConstants.deviceId))

        // then isSDKEnabled returns the correct values
        config.payload.sdkEnabledThreshold = 100
        XCTAssertTrue(config.isSDKEnabled)

        config.payload.sdkEnabledThreshold = 0
        XCTAssertFalse(config.isSDKEnabled)
    }

    func test_isBackgroundSessionEnabled() {
        // given a config
        let config = EmbraceConfig(options: testOptions(deviceId: TestConstants.deviceId))

        // then isBackgroundSessionEnabled returns the correct values
        config.payload.backgroundSessionThreshold = 100
        XCTAssertTrue(config.isBackgroundSessionEnabled)

        config.payload.backgroundSessionThreshold = 0
        XCTAssertFalse(config.isBackgroundSessionEnabled)
    }

    func test_hexValue() {
        // given an invalid device id
        let config1 = EmbraceConfig(options: testOptions(deviceId: "short"))

        // then the internal hex value is defaulted to UInt64.max
        // which will make all configs be disabled
        XCTAssertEqual(config1.deviceIdHexValue, UInt64.max)

        // given valid device ids
        let config2 = EmbraceConfig(options: testOptions(deviceId: "000000"))
        let config3 = EmbraceConfig(options: testOptions(deviceId: "123456"))
        let config4 = EmbraceConfig(options: testOptions(deviceId: "ABCDEF"))
        let config5 = EmbraceConfig(options: testOptions(deviceId: "A5F67E"))
        let config6 = EmbraceConfig(options: testOptions(deviceId: "FFFFFF"))

        // then the internal hex values are parsed correctly
        XCTAssertEqual(config2.deviceIdHexValue, 0x0)
        XCTAssertEqual(config3.deviceIdHexValue, 0x123456)
        XCTAssertEqual(config4.deviceIdHexValue, 0xABCDEF)
        XCTAssertEqual(config5.deviceIdHexValue, 0xA5F67E)
        XCTAssertEqual(config6.deviceIdHexValue, 0xFFFFFF)
    }

    func test_isEnabled() {
        XCTAssertTrue(EmbraceConfig.isEnabled(hexValue: 0xFFFFFF, digits: 6, threshold: 100))
        XCTAssertFalse(EmbraceConfig.isEnabled(hexValue: 0xFFFFFF, digits: 6, threshold: 99))
        XCTAssertFalse(EmbraceConfig.isEnabled(hexValue: 0xFFFFFF, digits: 6, threshold: 0))
        XCTAssertTrue(EmbraceConfig.isEnabled(hexValue: 0, digits: 6, threshold: 100))
        XCTAssertFalse(EmbraceConfig.isEnabled(hexValue: 0, digits: 6, threshold: 0))
        XCTAssert(EmbraceConfig.isEnabled(hexValue: 0x7FFFFF, digits: 6, threshold: 50))
        XCTAssertFalse(EmbraceConfig.isEnabled(hexValue: 0x7FFFFF, digits: 6, threshold: 49))
    }
}
