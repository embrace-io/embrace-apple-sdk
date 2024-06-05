//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceConfig

// swiftlint:disable force_try

class RemoteConfigPayloadTests: XCTestCase {

    func test_defaults() {
        // given an empty remote config
        let path = Bundle.module.path(forResource: "remote_config_empty", ofType: "json", inDirectory: "Mocks")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))

        // then the default values are used
        let payload = try! JSONDecoder().decode(RemoteConfigPayload.self, from: data)
        XCTAssertEqual(payload.sdkEnabledThreshold, 100)
        XCTAssertEqual(payload.backgroundSessionThreshold, 0)
        XCTAssertEqual(payload.networkSpansForwardingThreshold, 0)
        XCTAssertEqual(payload.internalLogsTraceLimit, 0)
        XCTAssertEqual(payload.internalLogsDebugLimit, 0)
        XCTAssertEqual(payload.internalLogsInfoLimit, 0)
        XCTAssertEqual(payload.internalLogsWarningLimit, 0)
        XCTAssertEqual(payload.internalLogsErrorLimit, 3)
    }

    func test_values() {
        // given a valid remote config
        let path = Bundle.module.path(forResource: "remote_config", ofType: "json", inDirectory: "Mocks")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))

        // then the values are correct
        let payload = try! JSONDecoder().decode(RemoteConfigPayload.self, from: data)
        XCTAssertEqual(payload.sdkEnabledThreshold, 50)
        XCTAssertEqual(payload.backgroundSessionThreshold, 75)
        XCTAssertEqual(payload.networkSpansForwardingThreshold, 25)
        XCTAssertEqual(payload.internalLogsTraceLimit, 10)
        XCTAssertEqual(payload.internalLogsDebugLimit, 20)
        XCTAssertEqual(payload.internalLogsInfoLimit, 30)
        XCTAssertEqual(payload.internalLogsWarningLimit, 40)
        XCTAssertEqual(payload.internalLogsErrorLimit, 50)
    }
}

// swiftlint:enable force_try
