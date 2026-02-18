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
        XCTAssertEqual(payload.networkSpansForwardingThreshold, 0)
        XCTAssertEqual(payload.uiLoadInstrumentationEnabled, true)
        XCTAssert(payload.viewControllerClassNameBlocklist.isEmpty)
        XCTAssertEqual(payload.uiInstrumentationCaptureHostingControllers, false)
        XCTAssertEqual(payload.swiftUiViewInstrumentationEnabled, true)
        XCTAssertEqual(payload.metricKitEnabledThreshold, 0)
        XCTAssertEqual(payload.metricKitCrashCaptureEnabled, false)
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
    }

    func testOnHavingValidRemoteConfig_RemoteConfigPayload_shouldOverridedDefaultValuesWithProvidedOnes() throws {
        // given a valid remote config
        let data = try getRemoteConfigData(forResource: "remote_config")

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then the values are correct
        XCTAssertEqual(payload.sdkEnabledThreshold, 50)
        XCTAssertEqual(payload.backgroundSessionThreshold, 75)
        XCTAssertEqual(payload.networkSpansForwardingThreshold, 25)
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
    }

    func test_onHavingOldAndInvalidRemoteConfigPayload_RemoteConfigPayload_shouldBeCreatedWithDefaults() throws {
        // given an invalid remote config
        let data = try getRemoteConfigData(forResource: "invalid_remote_config")

        // when decoding payload
        let payload = try XCTUnwrap(try JSONDecoder().decode(RemoteConfigPayload.self, from: data))

        // then the default values are used
        XCTAssertEqual(payload.sdkEnabledThreshold, 100)
        XCTAssertEqual(payload.backgroundSessionThreshold, 0)
        XCTAssertEqual(payload.networkSpansForwardingThreshold, 0)
        XCTAssertEqual(payload.uiLoadInstrumentationEnabled, true)
        XCTAssert(payload.viewControllerClassNameBlocklist.isEmpty)
        XCTAssertEqual(payload.uiInstrumentationCaptureHostingControllers, false)
        XCTAssertEqual(payload.swiftUiViewInstrumentationEnabled, true)
        XCTAssertEqual(payload.metricKitEnabledThreshold, 0)
        XCTAssertEqual(payload.metricKitCrashCaptureEnabled, false)
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
    }

    func getRemoteConfigData(forResource resource: String) throws -> Data {
        let path = try XCTUnwrap(Bundle.module.path(forResource: resource, ofType: "json", inDirectory: "Fixtures"))
        return try XCTUnwrap(Data(contentsOf: URL(fileURLWithPath: path)))
    }
}
