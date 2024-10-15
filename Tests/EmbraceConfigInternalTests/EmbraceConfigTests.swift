//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceConfigInternal
import EmbraceConfiguration

final class EmbraceConfigTests: XCTestCase {
    func buildConfig(
        configurable: EmbraceConfigurable,
        options: EmbraceConfig.Options = .init(minimumUpdateInterval: 5)
    ) -> EmbraceConfig {
        return EmbraceConfig(
            configurable: configurable,
            options: options,
            notificationCenter: .default,
            logger: MockLogger()
        )
    }

    // MARK: Update if Needed

    func test_updateIfNeeded_returnsTrueIfUpdateOccurs() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateExpectation.expectedFulfillmentCount = 1

        let config = buildConfig(configurable: mockConfig)

        let result1 = config.updateIfNeeded()
        XCTAssertTrue(result1)
        wait(for: [mockConfig.updateExpectation])

        let result2 = config.updateIfNeeded()
        XCTAssertFalse(result2)
    }

    func test_updateIfNeeded_returnsTrueIfTimeIntervalPassed() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateExpectation.expectedFulfillmentCount = 2

        let config = buildConfig(configurable: mockConfig, options: .init(minimumUpdateInterval: 0))

        let result1 = config.updateIfNeeded()
        XCTAssertTrue(result1)

        let result2 = config.updateIfNeeded()
        XCTAssertTrue(result2)

        wait(for: [mockConfig.updateExpectation], timeout: 1)
    }

    func test_updateIfNeeded_postsNotificationIf_configDidChange() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateCompletionParamDidUpdate = true
        mockConfig.updateExpectation.expectedFulfillmentCount = 1

        let config = buildConfig(configurable: mockConfig)

        let notificationExpectation = expectation(forNotification: .embraceConfigUpdated, object: config)

        let result1 = config.updateIfNeeded()
        XCTAssertTrue(result1)
        wait(for: [notificationExpectation])
    }

    func test_updateIfNeeded_doesNot_postNotificationIf_configDidNotChange() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateCompletionParamDidUpdate = false
        mockConfig.updateExpectation.expectedFulfillmentCount = 1

        let config = buildConfig(configurable: mockConfig)

        let notificationExpectation = expectation(forNotification: .embraceConfigUpdated, object: config)
        notificationExpectation.isInverted = true

        let result1 = config.updateIfNeeded()
        XCTAssertTrue(result1)
        wait(for: [notificationExpectation], timeout: .shortTimeout)
    }

    // MARK: appDidBecomeActive

    func test_appDidBecomeActive_callsUpdate() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateExpectation.expectedFulfillmentCount = 1

        _ = buildConfig(configurable: mockConfig)

        NotificationCenter.default.post(
            name: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)

        wait(for: [mockConfig.updateExpectation])
    }

    func test_appDidBecomeActive_afterUpdate_doesNotCallUpdate() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateExpectation.expectedFulfillmentCount = 1

        let config = buildConfig(configurable: mockConfig)
        config.update()

        NotificationCenter.default.post(
            name: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)

        wait(for: [mockConfig.updateExpectation])
    }

    func test_appDidBecomeActive_afterUpdate_doesCallUpdate_ifMinimumTimePassed() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateExpectation.expectedFulfillmentCount = 2

        let config = buildConfig(configurable: mockConfig, options: .init(minimumUpdateInterval: 0))

        let result1 = config.updateIfNeeded()
        XCTAssertTrue(result1)

        NotificationCenter.default.post(
            name: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)

        wait(for: [mockConfig.updateExpectation], timeout: 1)
    }

// MARK: Configurable Delegation

    func test_isSDKEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        let config = buildConfig(configurable: mockConfig)

        let result = config.isSDKEnabled
        XCTAssertEqual(result, mockConfig.isSDKEnabled)
        wait(for: [mockConfig.isSDKEnabledExpectation])
    }

    func test_isBackgroundSessionEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        let config = buildConfig(configurable: mockConfig)

        let result = config.isBackgroundSessionEnabled
        XCTAssertEqual(result, mockConfig.isBackgroundSessionEnabled)
        wait(for: [mockConfig.isBackgroundSessionEnabledExpectation])
    }

    func test_isNetworkSpansForwardingEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        let config = buildConfig(configurable: mockConfig)

        let result = config.isNetworkSpansForwardingEnabled
        XCTAssertEqual(result, mockConfig.isNetworkSpansForwardingEnabled)
        wait(for: [mockConfig.isNetworkSpansForwardingEnabledExpectation])
    }

    func test_internalLogLimits_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        let config = buildConfig(configurable: mockConfig)

        let result = config.internalLogLimits
        XCTAssertEqual(result, mockConfig.internalLogLimits)
        wait(for: [mockConfig.internalLogLimitsExpectation])
    }

    func test_networkPayloadCaptureRules_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        let config = buildConfig(configurable: mockConfig)

        let result = config.networkPayloadCaptureRules
        XCTAssertEqual(result, mockConfig.networkPayloadCaptureRules)
        wait(for: [mockConfig.networkPayloadCaptureRulesExpectation])
    }

}
