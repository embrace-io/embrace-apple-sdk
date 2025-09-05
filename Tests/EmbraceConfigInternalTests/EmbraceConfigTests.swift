//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import TestSupport
import XCTest

@testable import EmbraceConfigInternal

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
        let mockConfig = MockEmbraceConfigurable()
        config = buildConfig(configurable: mockConfig)

        let result = config.isSDKEnabled
        XCTAssertEqual(result, mockConfig.isSDKEnabled)
        wait(for: [mockConfig.isSDKEnabledExpectation])
    }

    func test_isBackgroundSessionEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        config = buildConfig(configurable: mockConfig)

        let result = config.isBackgroundSessionEnabled
        XCTAssertEqual(result, mockConfig.isBackgroundSessionEnabled)
        wait(for: [mockConfig.isBackgroundSessionEnabledExpectation])
    }

    func test_isNetworkSpansForwardingEnabled_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        config = buildConfig(configurable: mockConfig)

        let result = config.isNetworkSpansForwardingEnabled
        XCTAssertEqual(result, mockConfig.isNetworkSpansForwardingEnabled)
        wait(for: [mockConfig.isNetworkSpansForwardingEnabledExpectation])
    }

    func test_internalLogLimits_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        config = buildConfig(configurable: mockConfig)

        let result = config.internalLogLimits
        XCTAssertEqual(result, mockConfig.internalLogLimits)
        wait(for: [mockConfig.internalLogLimitsExpectation])
    }

    func test_networkPayloadCaptureRules_callsUnderlyingConfigurable() {
        let mockConfig = MockEmbraceConfigurable()
        config = buildConfig(configurable: mockConfig)

        let result = config.networkPayloadCaptureRules
        XCTAssertEqual(result, mockConfig.networkPayloadCaptureRules)
        wait(for: [mockConfig.networkPayloadCaptureRulesExpectation])
    }
}
