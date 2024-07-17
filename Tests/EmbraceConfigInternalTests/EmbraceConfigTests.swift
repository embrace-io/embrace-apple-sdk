//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceConfigInternal

class EmbraceConfigTests: XCTestCase {
    static var urlSessionConfig: URLSessionConfiguration!

    private var apiBaseUrl: String {
        "https://embrace.\(testName).com/config"
    }

    override func setUpWithError() throws {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = .max
        EmbraceConfigTests.urlSessionConfig = config
        EmbraceConfigTests.urlSessionConfig.protocolClasses = [EmbraceHTTPMock.self]
    }

    func testOptions(
        testName: String = #function,
        deviceId: String,
        minimumUpdateInterval: TimeInterval = 0
    ) -> EmbraceConfig.Options {
        return EmbraceConfig.Options(
            apiBaseUrl: apiBaseUrl,
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

    func mockSuccessfulResponse() throws {
        var url = try XCTUnwrap(URL(string: "\(apiBaseUrl)/v2/config"))

        if #available(iOS 16.0, *) {
            url.append(queryItems: [
                .init(name: "appId", value: TestConstants.appId),
                .init(name: "osVersion", value: TestConstants.osVersion),
                .init(name: "appVersion", value: TestConstants.appVersion),
                .init(name: "deviceId", value: TestConstants.deviceId),
                .init(name: "sdkVersion", value: TestConstants.sdkVersion)
            ])
        } else {
            XCTFail("This will fail on versions prior to iOS 16.0")
        }

        let path = Bundle.module.path(
            forResource: "remote_config",
            ofType: "json",
            inDirectory: "Mocks"
        )!
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        EmbraceHTTPMock.mock(url: url, response: .withData(data, statusCode: 200))
    }

    let logger = MockLogger()

    func test_frequentUpdatesIgnored() throws {
        // given a config with 1 hour minimum update interval
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 60 * 60
        )

        // Given the response is successful (necessary to save the `lastUpdateTime` value)
        try mockSuccessfulResponse()

        // Given an EmbraceConfig (executes fetch on init)
        let config = EmbraceConfig(options: options, notificationCenter: NotificationCenter.default, logger: logger)

        // Wait until the fetch from init has finished
        wait(timeout: .longTimeout) {
            config.updating == false
        }

        // when trying to update too soon
        config.updateIfNeeded()

        // then the update call is ignored
        let url = try XCTUnwrap(config.fetcher.buildURL())
        wait(timeout: .longTimeout) {
            return EmbraceHTTPMock.requestsForUrl(url).count == 1 &&
            EmbraceHTTPMock.totalRequestCount() == 1
        }
    }

    func test_frequentUpdatesNotIgnored() throws {
        // given a config with 1 second minimum update interval
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 1
        )

        // Given the response is successful (necessary to save the `lastUpdateTime` value)
        try mockSuccessfulResponse()

        // Given an EmbraceConfig (executes fetch on init)
        let config = EmbraceConfig(options: options, notificationCenter: NotificationCenter.default, logger: logger)

        // Wait until the fetch from init has finished
        wait(timeout: .longTimeout) {
            config.updating == false
        }

        // When invoking updateIfNeeded after waiting the "minimumUpdateInterval" amount assigned above
        wait(delay: 1)
        config.updateIfNeeded()

        // then the update call is not ignored
        let url = try XCTUnwrap(config.fetcher.buildURL())
        wait(timeout: .longTimeout) {
            return EmbraceHTTPMock.requestsForUrl(url).count == 2 &&
            EmbraceHTTPMock.totalRequestCount() == 2
        }
    }

    func test_forcedUpdateNotIgnored() throws {
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 60 * 60
        )

        // Given the response is successful (necessary to save the `lastUpdateTime` value)
        try mockSuccessfulResponse()

        // Given an EmbraceConfig (executes fetch on init)
        let config = EmbraceConfig(options: options, notificationCenter: NotificationCenter.default, logger: logger)

        // Wait until the fetch from init has finished
        wait(timeout: .longTimeout) {
            config.updating == false
        }

        // When forcing an update
        config.update()

        // then the update call is not ignored
        wait(timeout: .longTimeout) {
            config.updating == false
        }
        let url = try XCTUnwrap(config.fetcher.buildURL())
        wait(timeout: .longTimeout) {
            return EmbraceHTTPMock.requestsForUrl(url).count == 2 &&
            EmbraceHTTPMock.totalRequestCount() == 2
        }
    }

    func test_updateCallback() throws {
        expectation(forNotification: .embraceConfigUpdated, object: nil) { _ in
            return true
        }

        // given a config with 1 hour minimum update interval
        let options = testOptions(
            deviceId: TestConstants.deviceId,
            minimumUpdateInterval: 60 * 60
        )

        // Given the response is successful (necessary to save the `lastUpdateTime` value)
        try mockSuccessfulResponse()

        // Given an EmbraceConfig (executes fetch on init)
        let config = EmbraceConfig(options: options, notificationCenter: NotificationCenter.default, logger: logger)

        // making sure the fetched config is different so the notification is triggered
        config.payload.backgroundSessionThreshold = 12345

        config.update()

        waitForExpectations(timeout: .veryLongTimeout)
    }

    func test_invalidDeviceId() {
        // given a config with an invalid device id
        let config = EmbraceConfig(
            options: testOptions(deviceId: ""),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        // then all settings are disabled
        XCTAssertFalse(config.isSDKEnabled)
        XCTAssertFalse(config.isBackgroundSessionEnabled)
        XCTAssertFalse(config.isNetworkSpansForwardingEnabled)
    }

    func test_isSDKEnabled() {
        // given a config
        let config = EmbraceConfig(
            options: testOptions(deviceId: TestConstants.deviceId),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        // then isSDKEnabled returns the correct values
        config.payload.sdkEnabledThreshold = 100
        XCTAssertTrue(config.isSDKEnabled)

        config.payload.sdkEnabledThreshold = 0
        XCTAssertFalse(config.isSDKEnabled)
    }

    func test_isBackgroundSessionEnabled() {
        // given a config
        let config = EmbraceConfig(
            options: testOptions(deviceId: TestConstants.deviceId),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        // then isBackgroundSessionEnabled returns the correct values
        config.payload.backgroundSessionThreshold = 100
        XCTAssertTrue(config.isBackgroundSessionEnabled)

        config.payload.backgroundSessionThreshold = 0
        XCTAssertFalse(config.isBackgroundSessionEnabled)
    }

    func test_networkSpansForwardingEnabled() {
        // given a config
        let config = EmbraceConfig(
            options: testOptions(deviceId: TestConstants.deviceId),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        // then isNetworkSpansForwardingEnabled returns the correct values
        config.payload.networkSpansForwardingThreshold = 100
        XCTAssertTrue(config.isNetworkSpansForwardingEnabled)

        config.payload.networkSpansForwardingThreshold = 0
        XCTAssertFalse(config.isNetworkSpansForwardingEnabled)
    }

    func test_internalLogsLimits() {
        // given a config
        let config = EmbraceConfig(
            options: testOptions(deviceId: TestConstants.deviceId),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        // then test_internalLogsTraceLimit returns the correct values
        config.payload.internalLogsTraceLimit = 10
        config.payload.internalLogsDebugLimit = 20
        config.payload.internalLogsInfoLimit = 30
        config.payload.internalLogsWarningLimit = 40
        config.payload.internalLogsErrorLimit = 50

        XCTAssertEqual(config.internalLogsTraceLimit, 10)
        XCTAssertEqual(config.internalLogsDebugLimit, 20)
        XCTAssertEqual(config.internalLogsInfoLimit, 30)
        XCTAssertEqual(config.internalLogsWarningLimit, 40)
        XCTAssertEqual(config.internalLogsErrorLimit, 50)
    }

    func test_hexValue() {
        // given an invalid device id
        let config1 = EmbraceConfig(
            options: testOptions(deviceId: "short"),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )

        // then the internal hex value is defaulted to UInt64.max
        // which will make all configs be disabled
        XCTAssertEqual(config1.deviceIdHexValue, UInt64.max)

        // given valid device ids
        let config2 = EmbraceConfig(
            options: testOptions(deviceId: "000000"),
            notificationCenter: NotificationCenter.default,
            logger: logger
        )
        let config3 = EmbraceConfig(
            options: testOptions(deviceId: "123456"),
            notificationCenter: NotificationCenter.default,
            logger: logger)
        let config4 = EmbraceConfig(
            options: testOptions(deviceId: "ABCDEF"),
            notificationCenter: NotificationCenter.default,
            logger: logger)
        let config5 = EmbraceConfig(
            options: testOptions(deviceId: "A5F67E"),
            notificationCenter: NotificationCenter.default,
            logger: logger)
        let config6 = EmbraceConfig(
            options: testOptions(deviceId: "FFFFFF"),
            notificationCenter: NotificationCenter.default,
            logger: logger)

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
