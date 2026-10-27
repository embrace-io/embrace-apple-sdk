//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceConfigInternal
@testable import EmbraceConfiguration

final class EmbraceConfigTests: XCTestCase {

    var config: EmbraceConfig!

    func buildConfig(
        configurable: EmbraceConfigurable,
        options: EmbraceConfig.Options = .init(minimumUpdateInterval: 5)
    ) -> EmbraceConfig {
        return EmbraceConfig(
            configurable: configurable,
            options: options,
            notificationCenter: .default,
            logger: MockLogger(),
            queue: MockQueue()
        )
    }

    // MARK: Update if Needed

    func test_updateIfNeeded_doesNotCallUpdate_ifNotEnoughtimeHasPassed() {
        let mockConfig = MockEmbraceConfigurable()

        config = buildConfig(configurable: mockConfig)
        wait(timeout: 1) {
            return mockConfig.updateCallCount == 1
        }

        let result = config.updateIfNeeded()
        XCTAssertFalse(result)

        XCTAssertEqual(mockConfig.updateCallCount, 1)
    }

    func test_updateIfNeeded_callsUpdate_ifEnoughTimeHasPassed() {
        let mockConfig = MockEmbraceConfigurable()
        config = buildConfig(configurable: mockConfig, options: .init(minimumUpdateInterval: 0))

        let result1 = config.updateIfNeeded()
        XCTAssertTrue(result1)

        let result2 = config.updateIfNeeded()
        XCTAssertTrue(result2)

        wait(timeout: 3) {
            return mockConfig.updateCallCount == 3
        }
    }

    // MARK: Update notification

    func test_postsNotificationIf_configDidChange() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateCompletionParamDidUpdate = true

        let notificationExpectation = expectation(forNotification: .embraceConfigUpdated, object: nil)

        config = buildConfig(configurable: mockConfig)

        wait(for: [notificationExpectation], timeout: .shortTimeout)
    }

    func test_doesNot_postNotificationIf_configDidNotChange() {
        let mockConfig = MockEmbraceConfigurable()
        mockConfig.updateCompletionParamDidUpdate = false

        let notificationExpectation = expectation(forNotification: .embraceConfigUpdated, object: nil)
        notificationExpectation.isInverted = true

        config = buildConfig(configurable: mockConfig)

        wait(for: [notificationExpectation], timeout: .shortTimeout)
    }

    // MARK: appDidBecomeActive

    func test_appDidBecomeActive_afterEnoughTime_callsUpdate() {
        let mockConfig = MockEmbraceConfigurable()

        config = buildConfig(configurable: mockConfig, options: .init(minimumUpdateInterval: 0))

        NotificationCenter.default.post(
            name: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)

        wait(timeout: 2) {
            return mockConfig.updateCallCount == 2
        }
    }

    func test_appDidBecomeActive_afterUpdate_doesNotCallUpdate() {
        let mockConfig = MockEmbraceConfigurable()

        config = buildConfig(configurable: mockConfig)

        NotificationCenter.default.post(
            name: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)

        XCTAssertEqual(mockConfig.updateCallCount, 1)
    }

    // MARK: Configurable Delegation

    func test_isSDKEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable(isSDKEnabled: true)
        config = buildConfig(configurable: mockConfig)
        let callsBefore = mockConfig.isSDKEnabledCallCount

        XCTAssertTrue(config.isSDKEnabled)
        XCTAssertEqual(mockConfig.isSDKEnabledCallCount, callsBefore + 1)
    }

    func test_isBackgroundSessionEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable(isBackgroundSessionEnabled: true)
        config = buildConfig(configurable: mockConfig)
        let callsBefore = mockConfig.isBackgroundSessionEnabledCallCount

        XCTAssertTrue(config.isBackgroundSessionEnabled)
        XCTAssertEqual(mockConfig.isBackgroundSessionEnabledCallCount, callsBefore + 1)
    }

    func test_isNetworkSpansForwardingEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable(isNetworkSpansForwardingEnabled: true)
        config = buildConfig(configurable: mockConfig)
        let callsBefore = mockConfig.isNetworkSpansForwardingEnabledCallCount

        XCTAssertTrue(config.isNetworkSpansForwardingEnabled)
        XCTAssertEqual(mockConfig.isNetworkSpansForwardingEnabledCallCount, callsBefore + 1)
    }

    func test_internalLogLimits_callsUnderlyingConfigurable() {
        let limits = InternalLogLimits(trace: 1, debug: 2, info: 3, warning: 4, error: 5)
        let mockConfig = MockEmbraceConfigurable(internalLogLimits: limits)
        config = buildConfig(configurable: mockConfig)
        let callsBefore = mockConfig.internalLogLimitsCallCount

        XCTAssertEqual(config.internalLogLimits, limits)
        XCTAssertEqual(mockConfig.internalLogLimitsCallCount, callsBefore + 1)
    }

    func test_networkPayloadCaptureRules_callsUnderlyingConfigurable() {
        let rules = [
            NetworkPayloadCaptureRule(
                id: "rule",
                urlRegex: "https://example.com/.*",
                statusCodes: [500],
                method: "POST",
                expiration: 0,
                publicKey: ""
            )
        ]
        let mockConfig = MockEmbraceConfigurable(networkPayloadCaptureRules: rules)
        config = buildConfig(configurable: mockConfig)
        let callsBefore = mockConfig.networkPayloadCaptureRulesCallCount

        XCTAssertEqual(config.networkPayloadCaptureRules, rules)
        XCTAssertEqual(mockConfig.networkPayloadCaptureRulesCallCount, callsBefore + 1)
    }
}
