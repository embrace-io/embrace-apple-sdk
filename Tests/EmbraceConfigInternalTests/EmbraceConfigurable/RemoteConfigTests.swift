//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceConfigInternal
@testable import EmbraceConfiguration

final class RemoteConfigTests: XCTestCase {

    let logger = MockLogger()

    let options = RemoteConfig.Options(
        apiBaseUrl: "https://localhost:8080/config",
        queue: DispatchQueue(label: "com.test.embrace.queue"),
        appId: TestConstants.appId,
        deviceId: EmbraceIdentifier(stringValue: "00000000000000000000000000800000"),  // %50 threshold
        osVersion: TestConstants.osVersion,
        sdkVersion: TestConstants.sdkVersion,
        appVersion: TestConstants.appVersion,
        userAgent: TestConstants.userAgent,
        cacheLocation: nil,
        urlSessionConfiguration: URLSessionConfiguration.default
    )

    // MARK: Tests

    func test_isEnabled_returnsCorrectValues() {
        // True if threshold 100
        XCTAssertTrue(RemoteConfig.isEnabled(hexValue: 15, digits: 1, threshold: 100.0))
        // False if threshold 0
        XCTAssertFalse(RemoteConfig.isEnabled(hexValue: 0, digits: 1, threshold: 0.0))
        // True if threshold just under (128 limit)
        XCTAssertTrue(RemoteConfig.isEnabled(hexValue: 127, digits: 2, threshold: 50.0))
        // False if threshold just over (128 limit)
        XCTAssertFalse(RemoteConfig.isEnabled(hexValue: 129, digits: 2, threshold: 50.0))
    }

    func test_isSdkEnabled_usesPayloadThreshold() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        // then isSDKEnabled returns the correct values
        config.payload.sdkEnabledThreshold = 100
        XCTAssertTrue(config.isSDKEnabled)

        config.payload.sdkEnabledThreshold = 0
        XCTAssertFalse(config.isSDKEnabled)

        config.payload.sdkEnabledThreshold = 51
        XCTAssertTrue(config.isSDKEnabled)

        config.payload.sdkEnabledThreshold = 49
        XCTAssertFalse(config.isSDKEnabled)
    }

    func test_isBackgroundSessionEnabled() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        // then isBackgroundSessionEnabled returns the correct values
        config.payload.backgroundSessionThreshold = 100
        XCTAssertTrue(config.isBackgroundSessionEnabled)

        config.payload.backgroundSessionThreshold = 0
        XCTAssertFalse(config.isBackgroundSessionEnabled)

        config.payload.backgroundSessionThreshold = 51
        XCTAssertTrue(config.isBackgroundSessionEnabled)

        config.payload.backgroundSessionThreshold = 49
        XCTAssertFalse(config.isBackgroundSessionEnabled)
    }

    func test_networkSpansForwardingEnabled() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        // then isNetworkSpansForwardingEnabled returns the correct values based on nsf_pct_enabled
        config.payload.nsfThreshold = 100
        XCTAssertTrue(config.isNetworkSpansForwardingEnabled)

        config.payload.nsfThreshold = nil
        XCTAssertFalse(config.isNetworkSpansForwardingEnabled)

        config.payload.nsfThreshold = 51
        XCTAssertTrue(config.isNetworkSpansForwardingEnabled)

        config.payload.nsfThreshold = 49
        XCTAssertFalse(config.isNetworkSpansForwardingEnabled)
    }

    func test_traceparentInjectionEnabled() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        // then traceparentInjectionEnabled returns the correct values based on traceparent_injection_pct_enabled
        config.payload.traceparentInjectionThreshold = 100
        XCTAssertTrue(config.traceparentInjectionEnabled)

        config.payload.traceparentInjectionThreshold = nil
        XCTAssertFalse(config.traceparentInjectionEnabled)

        config.payload.traceparentInjectionThreshold = 51
        XCTAssertTrue(config.traceparentInjectionEnabled)

        config.payload.traceparentInjectionThreshold = 49
        XCTAssertFalse(config.traceparentInjectionEnabled)
    }

    func test_SpanEventsLimits() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        config.payload.breadcrumbLimit = 987
        config.payload.tapLimit = 654

        XCTAssertEqual(
            config.spanEventTypeLimits,
            SpanEventTypeLimits(breadcrumb: 987, tap: 654)
        )
    }

    func test_LogsLimits() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        config.payload.logsInfoLimit = 10
        config.payload.logsWarningLimit = 20
        config.payload.logsErrorLimit = 30

        XCTAssertEqual(
            config.logSeverityLimits,
            LogSeverityLimits(info: 10, warn: 20, error: 30)
        )
    }

    func test_internalLogLimits() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        config.payload.internalLogsTraceLimit = 10
        config.payload.internalLogsDebugLimit = 20
        config.payload.internalLogsInfoLimit = 30
        config.payload.internalLogsWarningLimit = 40
        config.payload.internalLogsErrorLimit = 50

        XCTAssertEqual(
            config.internalLogLimits,
            InternalLogLimits(trace: 10, debug: 20, info: 30, warning: 40, error: 50)
        )
    }

    func test_experimentsLimits() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        config.payload.maxExperimentCount = 1000
        config.payload.maxExperimentIdLength = 256
        config.payload.maxExperimentVariantLength = 64

        XCTAssertEqual(
            config.experimentsLimits,
            ExperimentsLimits(maxCount: 1000, maxIdLength: 256, maxVariantLength: 64)
        )
    }

    func test_experimentsLimits_clampsOutOfRangePayloadValues() {
        // given a config with payload values above the ceilings
        let config = RemoteConfig(options: options, logger: logger)

        config.payload.maxExperimentCount = 6000
        config.payload.maxExperimentIdLength = 2048
        config.payload.maxExperimentVariantLength = 2048

        // then the limits are clamped
        let limits = config.experimentsLimits
        XCTAssertEqual(limits.maxCount, ExperimentsLimits.maxSettableCount)
        XCTAssertEqual(limits.maxIdLength, ExperimentsLimits.maxSettableIdLength)
        XCTAssertEqual(limits.maxVariantLength, ExperimentsLimits.maxSettableVariantLength)
    }

    func test_experimentsLimits_fallsBackToDefaultsForNegativePayloadValues() {
        // given a config with malformed (negative) payload values
        let config = RemoteConfig(options: options, logger: logger)

        config.payload.maxExperimentCount = -1
        config.payload.maxExperimentIdLength = -1
        config.payload.maxExperimentVariantLength = -1

        // then the built-in defaults are used
        XCTAssertEqual(config.experimentsLimits, ExperimentsLimits())
    }

    func test_networkPayloadCaptureRules() {
        // given a config
        let config = RemoteConfig(options: options, logger: logger)

        let rule1 = NetworkPayloadCaptureRule(
            id: "test1",
            urlRegex: "https://example.com/.*",
            statusCodes: [200],
            method: "GET",
            expiration: 0,
            publicKey: ""
        )

        let rule2 = NetworkPayloadCaptureRule(
            id: "test2",
            urlRegex: "https://test.com/.*",
            statusCodes: [404],
            method: "GET",
            expiration: 0,
            publicKey: ""
        )

        config.payload.networkPayloadCaptureRules = [rule1, rule2]
        XCTAssertEqual(config.networkPayloadCaptureRules, [rule1, rule2])
    }

    // MARK: - Hang limit corrections

    func test_hangLimitCorrections_emptyForValidPayload() {
        // Default payload values are all in range.
        XCTAssertTrue(RemoteConfig.hangLimitCorrections(for: RemoteConfigPayload()).isEmpty)
    }

    func test_hangLimitCorrections_reportsClampForOutOfRangeSampleTrigger() {
        var payload = RemoteConfigPayload()
        payload.hangLimitsSampleTriggerThreshold = 0.0001  // below floor, still < hangThreshold → clamp
        let corrections = RemoteConfig.hangLimitCorrections(for: payload)
        XCTAssertEqual(corrections.count, 1)
        let msg = corrections.first ?? ""
        XCTAssertTrue(msg.contains("sample_trigger_threshold"))
        XCTAssertTrue(msg.contains("clamped"), "an out-of-range trigger should be reported as a clamp: \(msg)")
    }

    func test_hangLimitCorrections_reportsCapWhenTriggerAtOrAboveHangThreshold() {
        var payload = RemoteConfigPayload()
        payload.hangLimitsHangThreshold = 0.1
        payload.hangLimitsSampleTriggerThreshold = 0.15  // >= hangThreshold → capped below it
        let msg = RemoteConfig.hangLimitCorrections(for: payload).first { $0.contains("sample_trigger_threshold") } ?? ""
        XCTAssertTrue(msg.contains("capped"), "a trigger >= hang_threshold should be reported as capped: \(msg)")
    }

    func test_hangLimitCorrections_reportsAboveMaxForOversizedSampleTrigger() {
        var payload = RemoteConfigPayload()
        payload.hangLimitsSampleTriggerThreshold = 5000  // > max → likely a seconds/ms mixup
        let msg = RemoteConfig.hangLimitCorrections(for: payload).first { $0.contains("sample_trigger_threshold") } ?? ""
        XCTAssertTrue(msg.contains("above the max"), "an oversized trigger should be reported as above the max: \(msg)")
    }

    func test_hangLimitCorrections_silentForInRangeTriggerTrimmedByCap() {
        // 0.2 is a valid request (< hangThreshold) that the routine 60% cap trims to ~0.149. That's
        // expected policy, not a misconfiguration, so it must NOT be reported.
        var payload = RemoteConfigPayload()
        payload.hangLimitsHangThreshold = 0.249
        payload.hangLimitsSampleTriggerThreshold = 0.2
        XCTAssertFalse(
            RemoteConfig.hangLimitCorrections(for: payload).contains { $0.contains("sample_trigger_threshold") },
            "a valid-but-capped trigger should not be reported as a correction")
    }

    func test_hangLimitCorrections_reportsFallbackForNonFiniteSampleTrigger() {
        var payload = RemoteConfigPayload()
        payload.hangLimitsSampleTriggerThreshold = .nan
        let msg = RemoteConfig.hangLimitCorrections(for: payload).first { $0.contains("sample_trigger_threshold") } ?? ""
        XCTAssertTrue(msg.contains("not finite"), "a non-finite trigger should be reported as a fallback: \(msg)")
    }

    func test_hangLimitCorrections_reportsClampForOutOfRangeSamplePollInterval() {
        var payload = RemoteConfigPayload()
        payload.hangLimitsSamplePollInterval = 5000
        let corrections = RemoteConfig.hangLimitCorrections(for: payload)
        XCTAssertEqual(corrections.count, 1)
        let msg = corrections.first ?? ""
        XCTAssertTrue(msg.contains("sample_poll_interval"))
        XCTAssertTrue(msg.contains("clamped"), "an out-of-range poll interval should be reported as a clamp: \(msg)")
    }

    func test_hangLimitCorrections_flagsNonPositiveHangThreshold() {
        var payload = RemoteConfigPayload()
        payload.hangLimitsHangThreshold = -1
        XCTAssertTrue(RemoteConfig.hangLimitCorrections(for: payload).contains { $0.contains("hang_threshold") })
    }

    // MARK: - Hang correction logging is wired into config updates

    func test_update_logsHangCorrections_onlyWhenPayloadChanges() {
        let recording = MockLogger()
        let fetcher = StubRemoteConfigFetcher(options: options, logger: recording)
        let config = RemoteConfig(options: options, fetcher: fetcher, logger: recording)

        var bad = RemoteConfigPayload()
        bad.hangLimitsSampleTriggerThreshold = 5000  // out of range → HangLimits corrects it
        fetcher.payloadToReturn = bad

        func hangWarnings() -> Int {
            recording.loggedMessages.filter { $0.message.contains("[Hang] remote config value out of range") }.count
        }

        // First fetch: payload changed from the default → the correction is logged once.
        config.update { _ in }
        XCTAssertEqual(hangWarnings(), 1, "a changed out-of-range payload should log its correction")

        // Second fetch: identical payload → didUpdate is false → must not re-log.
        config.update { _ in }
        XCTAssertEqual(hangWarnings(), 1, "an unchanged payload must not re-log (didUpdate gate)")
    }
}

/// Returns a canned payload synchronously instead of hitting the network.
private final class StubRemoteConfigFetcher: RemoteConfigFetcher {
    var payloadToReturn: RemoteConfigPayload?
    override func fetch(completion: @escaping (RemoteConfigPayload?, Data?) -> Void) {
        completion(payloadToReturn, nil)
    }
}
