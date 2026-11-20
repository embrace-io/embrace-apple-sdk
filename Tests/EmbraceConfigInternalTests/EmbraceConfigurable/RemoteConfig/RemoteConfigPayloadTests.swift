//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceConfigInternal

class RemoteConfigPayloadTests: XCTestCase {

    func testOnReceivingEmptyRemoteConfig_RemoteConfigPayload_shouldUseDefaultValues() throws {
        // given an empty remote config
        let data = try getRemoteConfigData(forResource: "remote_config_empty")

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then the default values are used
        XCTAssertEqual(payload.sdkEnabledThreshold, 100)
        XCTAssertEqual(payload.backgroundSessionThreshold, 0)
        XCTAssertNil(payload.nsfThreshold)
        XCTAssertNil(payload.traceparentInjectionThreshold)
        XCTAssertNil(payload.smoothnessThreshold)
        XCTAssertEqual(payload.smoothnessIdleThreshold, 0.1)
        XCTAssertEqual(payload.smoothnessHeldIdleThreshold, 0.5)
        XCTAssertEqual(payload.smoothnessSpanLimit, 250)
        XCTAssertEqual(payload.smoothnessFrameTraceThreshold, 0)
        XCTAssertEqual(payload.uiLoadInstrumentationEnabled, true)
        XCTAssert(payload.viewControllerClassNameBlocklist.isEmpty)
        XCTAssertEqual(payload.uiInstrumentationCaptureHostingControllers, false)
        XCTAssertEqual(payload.swiftUiViewInstrumentationEnabled, true)
        XCTAssertEqual(payload.metricKitEnabledThreshold, 100)
        XCTAssertEqual(payload.metricKitCrashCaptureEnabled, true)
        XCTAssertEqual(payload.metricKitCrashSignals, ["SIGKILL"])
        XCTAssertEqual(payload.metricKitHangCaptureEnabled, false)
        XCTAssertEqual(payload.breadcrumbLimit, 100)
        XCTAssertEqual(payload.tapLimit, 80)
        XCTAssertEqual(payload.logsInfoLimit, 100)
        XCTAssertEqual(payload.logsWarningLimit, 200)
        XCTAssertEqual(payload.logsErrorLimit, 500)
        XCTAssertEqual(payload.internalLogsTraceLimit, 0)
        XCTAssertEqual(payload.internalLogsDebugLimit, 0)
        XCTAssertEqual(payload.internalLogsInfoLimit, 0)
        XCTAssertEqual(payload.internalLogsWarningLimit, 0)
        XCTAssertEqual(payload.internalLogsErrorLimit, 3)
        XCTAssertEqual(payload.networkPayloadCaptureRules.count, 0)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
        XCTAssertEqual(payload.hangLimitsHangThreshold, 0.249)
        XCTAssertEqual(payload.hangLimitsSampleTriggerThreshold, 0.15)
        XCTAssertEqual(payload.hangLimitsSamplePollInterval, 0.05)
        XCTAssertEqual(payload.maxExperimentCount, 500)
        XCTAssertEqual(payload.maxExperimentIdLength, 128)
        XCTAssertEqual(payload.maxExperimentVariantLength, 128)
    }

    func testOnHavingValidRemoteConfig_RemoteConfigPayload_shouldOverridedDefaultValuesWithProvidedOnes() throws {
        // given a valid remote config
        let data = try getRemoteConfigData(forResource: "remote_config")

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then the values are correct
        XCTAssertEqual(payload.sdkEnabledThreshold, 50)
        XCTAssertEqual(payload.backgroundSessionThreshold, 75)
        XCTAssertEqual(payload.nsfThreshold, 25)
        XCTAssertEqual(payload.traceparentInjectionThreshold, 10)
        XCTAssertEqual(payload.smoothnessThreshold, 5)
        XCTAssertEqual(payload.smoothnessIdleThreshold, 0.15)
        XCTAssertEqual(payload.smoothnessHeldIdleThreshold, 0.75)
        XCTAssertEqual(payload.smoothnessSpanLimit, 100)
        XCTAssertEqual(payload.smoothnessFrameTraceThreshold, 2.5)
        XCTAssertEqual(payload.uiLoadInstrumentationEnabled, false)
        XCTAssertEqual(payload.viewControllerClassNameBlocklist, ["MYVIEWCONTROLLER", "TESTVIEWCONTROLLER"])
        XCTAssertEqual(payload.uiInstrumentationCaptureHostingControllers, true)
        XCTAssertEqual(payload.swiftUiViewInstrumentationEnabled, false)
        XCTAssertEqual(payload.breadcrumbLimit, 1234)
        XCTAssertEqual(payload.tapLimit, 1234)
        XCTAssertEqual(payload.logsInfoLimit, 40)
        XCTAssertEqual(payload.logsWarningLimit, 50)
        XCTAssertEqual(payload.logsErrorLimit, 60)
        XCTAssertEqual(payload.internalLogsTraceLimit, 10)
        XCTAssertEqual(payload.internalLogsDebugLimit, 20)
        XCTAssertEqual(payload.internalLogsInfoLimit, 30)
        XCTAssertEqual(payload.internalLogsWarningLimit, 40)
        XCTAssertEqual(payload.internalLogsErrorLimit, 50)
        XCTAssertEqual(payload.networkPayloadCaptureRules.count, 2)

        let rule1 = payload.networkPayloadCaptureRules.first { $0.id == "rule1" }
        XCTAssertEqual(rule1!.urlRegex, "www.test.com/user/*")
        XCTAssertEqual(rule1!.statusCodes, [200, 201, 404, -1])
        XCTAssertEqual(rule1!.method, "GET")
        XCTAssertEqual(rule1!.expiration, 1_723_570_602)
        XCTAssertEqual(rule1!.publicKey, "key")

        let rule2 = payload.networkPayloadCaptureRules.first { $0.id == "rule2" }
        XCTAssertEqual(rule2!.urlRegex, "www.test.com/test")
        XCTAssertNil(rule2!.statusCodes)
        XCTAssertNil(rule2!.method)
        XCTAssertEqual(rule2!.expiration, 1_723_570_602)
        XCTAssertEqual(rule2!.publicKey, "key")

        XCTAssertEqual(payload.metricKitEnabledThreshold, 55)
        XCTAssertEqual(payload.metricKitCrashCaptureEnabled, true)
        XCTAssertEqual(payload.metricKitCrashSignals, ["SIGKILL", "SIGINT"])
        XCTAssertEqual(payload.metricKitHangCaptureEnabled, true)
        XCTAssertEqual(payload.hangLimitsHangThreshold, 0.5)
        XCTAssertEqual(payload.hangLimitsHangPerSession, 100)
        XCTAssertEqual(payload.hangLimitsSampleTriggerThreshold, 0.2)
        XCTAssertEqual(payload.hangLimitsSamplePollInterval, 0.03)
        XCTAssertEqual(payload.maxExperimentCount, 1000)
        XCTAssertEqual(payload.maxExperimentIdLength, 256)
        XCTAssertEqual(payload.maxExperimentVariantLength, 64)
    }

    func test_onHavingSomeExperimentKeys_RemoteConfigPayload_shouldUseDefaultsForMissingOnes() throws {
        // given a remote config that only sets one of the experiment keys
        let data = Data(
            """
            {
                "experiment_id_max_length": 256
            }
            """.utf8)

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then only the provided key is overridden
        XCTAssertEqual(payload.maxExperimentCount, 500)
        XCTAssertEqual(payload.maxExperimentIdLength, 256)
        XCTAssertEqual(payload.maxExperimentVariantLength, 128)
    }

    func test_onHavingOutOfRangeExperimentValues_RemoteConfigPayload_shouldDecodeThemVerbatim() throws {
        // given a remote config with values outside the allowed range
        let data = Data(
            """
            {
                "experiment_max_count": 999999,
                "experiment_id_max_length": -1,
                "experiment_variant_max_length": 0
            }
            """.utf8)

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then the payload carries them as-is; clamping is `ExperimentsLimits`' job
        XCTAssertEqual(payload.maxExperimentCount, 999999)
        XCTAssertEqual(payload.maxExperimentIdLength, -1)
        XCTAssertEqual(payload.maxExperimentVariantLength, 0)
    }

    func test_onHavingOldAndInvalidRemoteConfigPayload_RemoteConfigPayload_shouldBeCreatedWithDefaults() throws {
        // given an invalid remote config
        let data = try getRemoteConfigData(forResource: "invalid_remote_config")

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then the default values are used
        XCTAssertEqual(payload.sdkEnabledThreshold, 100)
        XCTAssertEqual(payload.backgroundSessionThreshold, 0)
        XCTAssertNil(payload.nsfThreshold)
        XCTAssertNil(payload.traceparentInjectionThreshold)
        XCTAssertEqual(payload.uiLoadInstrumentationEnabled, true)
        XCTAssert(payload.viewControllerClassNameBlocklist.isEmpty)
        XCTAssertEqual(payload.uiInstrumentationCaptureHostingControllers, false)
        XCTAssertEqual(payload.swiftUiViewInstrumentationEnabled, true)
        XCTAssertEqual(payload.metricKitEnabledThreshold, 100)
        XCTAssertEqual(payload.metricKitCrashCaptureEnabled, true)
        XCTAssertEqual(payload.metricKitCrashSignals, ["SIGKILL"])
        XCTAssertEqual(payload.metricKitHangCaptureEnabled, false)
        XCTAssertEqual(payload.breadcrumbLimit, 100)
        XCTAssertEqual(payload.tapLimit, 80)
        XCTAssertEqual(payload.logsInfoLimit, 100)
        XCTAssertEqual(payload.logsWarningLimit, 200)
        XCTAssertEqual(payload.logsErrorLimit, 500)
        XCTAssertEqual(payload.internalLogsTraceLimit, 0)
        XCTAssertEqual(payload.internalLogsDebugLimit, 0)
        XCTAssertEqual(payload.internalLogsInfoLimit, 0)
        XCTAssertEqual(payload.internalLogsWarningLimit, 0)
        XCTAssertEqual(payload.internalLogsErrorLimit, 3)
        XCTAssertEqual(payload.networkPayloadCaptureRules.count, 0)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
        XCTAssertEqual(payload.hangLimitsHangThreshold, 0.249)
        XCTAssertEqual(payload.hangLimitsSampleTriggerThreshold, 0.15)
        XCTAssertEqual(payload.hangLimitsSamplePollInterval, 0.05)
        XCTAssertEqual(payload.maxExperimentCount, 500)
        XCTAssertEqual(payload.maxExperimentIdLength, 128)
        XCTAssertEqual(payload.maxExperimentVariantLength, 128)
    }

    // MARK: - Data section

    func test_networkSpanParentProviderSlowThreshold_missing_usesDefault() throws {
        XCTAssertEqual(try decodePayload("{}").networkSpanParentProviderSlowThreshold, 0.005)
        XCTAssertEqual(try decodePayload(#"{ "data": {} }"#).networkSpanParentProviderSlowThreshold, 0.005)
    }

    func test_networkSpanParentProviderSlowThreshold_valid_isConvertedToSeconds() throws {
        let payload = try decodePayload(#"{ "data": { "network_span_parent_provider_slow_ms": 20 } }"#)
        XCTAssertEqual(payload.networkSpanParentProviderSlowThreshold, 0.020)
    }

    func test_networkSpanParentProviderSlowThreshold_fractional_isKept() throws {
        let payload = try decodePayload(#"{ "data": { "network_span_parent_provider_slow_ms": 2.5 } }"#)
        XCTAssertEqual(payload.networkSpanParentProviderSlowThreshold, 0.0025)
    }

    func test_networkSpanParentProviderSlowThreshold_zeroOrNegative_usesDefault() throws {
        XCTAssertEqual(
            try decodePayload(#"{ "data": { "network_span_parent_provider_slow_ms": 0 } }"#).networkSpanParentProviderSlowThreshold,
            0.005
        )
        XCTAssertEqual(
            try decodePayload(#"{ "data": { "network_span_parent_provider_slow_ms": -10 } }"#).networkSpanParentProviderSlowThreshold,
            0.005
        )
    }

    func test_networkSpanParentProviderSlowThreshold_malformed_usesDefault_andKeepsTheRestOfTheConfig() throws {
        let payload = try decodePayload(#"{ "threshold": 50, "data": { "network_span_parent_provider_slow_ms": "fast" } }"#)
        XCTAssertEqual(payload.networkSpanParentProviderSlowThreshold, 0.005)
        XCTAssertEqual(payload.sdkEnabledThreshold, 50)

        let notAnObject = try decodePayload(#"{ "threshold": 50, "data": 20 }"#)
        XCTAssertEqual(notAnObject.networkSpanParentProviderSlowThreshold, 0.005)
        XCTAssertEqual(notAnObject.sdkEnabledThreshold, 50)
    }

    func test_networkSpanParentProviderSlowThreshold_atTheRoot_isIgnored() throws {
        let payload = try decodePayload(#"{ "network_span_parent_provider_slow_ms": 20 }"#)
        XCTAssertEqual(payload.networkSpanParentProviderSlowThreshold, 0.005)
    }

    // MARK: - User session config

    private func decodePayload(_ json: String) throws -> RemoteConfigPayload {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(RemoteConfigPayload.self, from: data)
    }

    func test_userSession_blockMissing_usesDefaults() throws {
        let payload = try decodePayload("{}")
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    func test_userSession_bothFieldsPresentAndValid_usesProvidedValues() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 21600, "inactivity_timeout_seconds": 600 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 21600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 600)
    }

    func test_userSession_maxBelowRange_fallsBackToDefault() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 60, "inactivity_timeout_seconds": 600 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 600)
    }

    func test_userSession_maxAboveRange_fallsBackToDefault() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 999999, "inactivity_timeout_seconds": 600 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 600)
    }

    func test_userSession_inactivityBelowRange_fallsBackToDefault() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 21600, "inactivity_timeout_seconds": 5 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 21600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    func test_userSession_inactivityAboveRange_fallsBackToDefault() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 21600, "inactivity_timeout_seconds": 999999 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 21600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    func test_userSession_inactivityGreaterThanMax_forcesInactivityToDefault() throws {
        // Both fields are individually within their valid range, but the cross-field
        // constraint (`inactivity <= max`) is violated. Force `inactivity = 30 * 60`,
        // keep `max` as provided.
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 3600, "inactivity_timeout_seconds": 7200 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    func test_userSession_inactivityEqualToMax_keepsBothAsProvided() throws {
        // Boundary is inclusive (<=).
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 3600, "inactivity_timeout_seconds": 3600 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 3600)
    }

    func test_userSession_malformedTypes_fallsBackToDefaults() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": "not a number", "inactivity_timeout_seconds": null } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    func test_userSession_emptyBlock_usesDefaults() throws {
        let payload = try decodePayload(#"{ "user_session": {} }"#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 12 * 3600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    func test_userSession_onlyMaxPresent_inactivityDefaults() throws {
        let payload = try decodePayload(
            #"""
            { "user_session": { "max_duration_seconds": 21600 } }
            """#)
        XCTAssertEqual(payload.userSessionMaxDurationSeconds, 21600)
        XCTAssertEqual(payload.userSessionInactivityTimeoutSeconds, 30 * 60)
    }

    // MARK: - Vitals config

    func test_vitals_onlySomeKeysPresent_usesDefaultsForMissingOnes() throws {
        let payload = try decodePayload(#"{ "vitals": { "smoothness_held_idle_threshold_ms": 800 } }"#)
        XCTAssertEqual(payload.smoothnessIdleThreshold, 0.1)
        XCTAssertEqual(payload.smoothnessHeldIdleThreshold, 0.8)
        XCTAssertEqual(payload.smoothnessSpanLimit, 250)
    }

    func test_vitals_malformedTypes_fallBackToDefaultsPerKey() throws {
        let payload = try decodePayload(
            #"""
            { "vitals": { "smoothness_idle_threshold_ms": "fast", "smoothness_held_idle_threshold_ms": 600, "span_limit": null, "smoothness_frame_trace_pct_enabled": "all" } }
            """#)
        XCTAssertEqual(payload.smoothnessIdleThreshold, 0.1)
        XCTAssertEqual(payload.smoothnessHeldIdleThreshold, 0.6)
        XCTAssertEqual(payload.smoothnessSpanLimit, 250)
        XCTAssertEqual(payload.smoothnessFrameTraceThreshold, 0)
    }

    func test_vitals_notAnObject_usesDefaults() throws {
        let payload = try decodePayload(#"{ "vitals": 1, "smoothness_pct_enabled": 5 }"#)
        XCTAssertEqual(payload.smoothnessThreshold, 5)
        XCTAssertEqual(payload.smoothnessIdleThreshold, 0.1)
        XCTAssertEqual(payload.smoothnessHeldIdleThreshold, 0.5)
        XCTAssertEqual(payload.smoothnessSpanLimit, 250)
    }

    // MARK: - State capture

    func test_stateCapture_keysAbsent_areNil() throws {
        // absent keys must stay nil so the `?? 0` at the read site resolves to "off"
        let payload = try decodePayload("{}")
        XCTAssertNil(payload.stateCaptureThreshold)
        XCTAssertNil(payload.screenTrackingThreshold)
    }

    func test_stateCapture_keysPresent_areDecoded() throws {
        let payload = try decodePayload(
            #"""
            { "pct_state_enabled_v2": 100, "pct_screen_tracking_enabled": 50 }
            """#)
        XCTAssertEqual(payload.stateCaptureThreshold, 100)
        XCTAssertEqual(payload.screenTrackingThreshold, 50)
    }

    func test_stateCapture_malformedValues_fallBackToNil() throws {
        // a bad backend value must fail closed (nil -> off), not throw and take the whole payload down
        let payload = try decodePayload(
            #"""
            { "pct_state_enabled_v2": "not a number", "pct_screen_tracking_enabled": true }
            """#)
        XCTAssertNil(payload.stateCaptureThreshold)
        XCTAssertNil(payload.screenTrackingThreshold)
    }

    func getRemoteConfigData(forResource resource: String) throws -> Data {
        let path = try XCTUnwrap(Bundle.module.path(forResource: resource, ofType: "json", inDirectory: "Fixtures"))
        return try XCTUnwrap(Data(contentsOf: URL(fileURLWithPath: path)))
    }
}
