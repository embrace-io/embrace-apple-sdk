//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceStorage
@testable import EmbraceCommon
import TestSupport

// swiftlint:disable force_cast line_length

final class SessionPayloadTests: XCTestCase {
    let options = EmbraceStorage.Options(baseUrl: URL(fileURLWithPath: NSTemporaryDirectory()), fileName: "test.sqlite")

    let mockAppInfoResources: [MetadataRecord] = [
        .init(
            key: AppResourceKey.bundleVersion.rawValue,
            value: .string("fake_bundle_version"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: AppResourceKey.environment.rawValue,
            value: .string("fake_environment"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: AppResourceKey.detailedEnvironment.rawValue,
            value: .string("fake_detailed_environment"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: AppResourceKey.framework.rawValue,
            value: .string("1"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: AppResourceKey.launchCount.rawValue,
            value: .string("2"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: AppResourceKey.sdkVersion.rawValue,
            value: .string("fake_sdk_version"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: AppResourceKey.appVersion.rawValue,
            value: .string("fake_app_version"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        )
    ]

    let mockDeviceInfoResources: [MetadataRecord] = [
        .init(
            key: DeviceResourceKey.isJailbroken.rawValue,
            value: .string("false"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.locale.rawValue,
            value: .string("fake_locale"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.timezone.rawValue,
            value: .string("fake_timezone"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.totalDiskSpace.rawValue,
            value: .string("123456"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.architecture.rawValue,
            value: .string("fake_architecture"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.model.rawValue,
            value: .string("fake_model"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.manufacturer.rawValue,
            value: .string("fake_manufacturer"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.screenResolution.rawValue,
            value: .string("fake_screen_resolution"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.osVersion.rawValue,
            value: .string("fake_os_version"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.osBuild.rawValue,
            value: .string("fake_os_build"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.osType.rawValue,
            value: .string("fake_os_type"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        ),
        .init(
            key: DeviceResourceKey.osVariant.rawValue,
            value: .string("fake_os_variant"),
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.hex
        )
    ]

    var mockSessionRecord: SessionRecord {
        .init(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 10),
            endTime: Date(timeIntervalSince1970: 40),
            coldStart: true,
            cleanExit: true,
            appTerminated: false)
    }

    func test_properties() {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockMetadataFetcher(metadata: [])

        // when creating a payload
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher, counter: 10)

        // then the properties are correctly set
        XCTAssertEqual(payload.messageFormatVersion, 15)
        XCTAssertEqual(payload.sessionInfo.sessionId, sessionRecord.id)
        XCTAssertEqual(payload.sessionInfo.startTime, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.endTime, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.lastHeartbeatTime, sessionRecord.lastHeartbeatTime.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.appState, sessionRecord.state)
        XCTAssertEqual(payload.sessionInfo.counter, 10)
        XCTAssertEqual(payload.sessionInfo.appTerminated, false)
        XCTAssertEqual(payload.sessionInfo.cleanExit, true)
        XCTAssertEqual(payload.sessionInfo.coldStart, true)
    }

    func test_highLevelKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockMetadataFetcher(metadata: [])

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the payload has all the necessary high level keys
        XCTAssertNotNil(json["v"])
        XCTAssertEqual(json["v"] as! Int, 15)
        XCTAssertNotNil(json["s"])
        XCTAssertNotNil(json["a"])
        XCTAssertNotNil(json["d"])
        XCTAssertNotNil(json["u"])
        XCTAssertNotNil(json["spans"])
    }

    func test_sessionInfoKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockMetadataFetcher(metadata: [])

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher, counter: 10)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let sessionInfo = json["s"] as! [String: Any]
        XCTAssertEqual(sessionInfo["id"] as! String, sessionRecord.id.toString)
        XCTAssertEqual(sessionInfo["st"] as! Int, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["et"] as? Int, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["ht"] as! Int, sessionRecord.lastHeartbeatTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["as"] as! String, sessionRecord.state)
        XCTAssertEqual(sessionInfo["sn"] as! Int, 10)
        XCTAssertEqual(sessionInfo["tr"] as! Bool, false)
        XCTAssertEqual(sessionInfo["ce"] as! Bool, true)
        XCTAssertEqual(sessionInfo["cs"] as! Bool, true)
    }

    func test_sessionInfoKeys_withSessionProperties() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockMetadataFetcher(metadata: [
            MetadataRecord(
            key: "foo",
            value: .string("bar"),
            type: .customProperty,
            lifespan: .session, lifespanId: sessionRecord.id.toString, collectedAt: Date()
            )
        ])

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher, counter: 10)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let sessionInfo = json["s"] as! [String: Any]
        XCTAssertEqual(sessionInfo.keys.count, 10)
        XCTAssertEqual(sessionInfo["id"] as! String, sessionRecord.id.toString)
        XCTAssertEqual(sessionInfo["st"] as! Int, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["et"] as? Int, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["ht"] as! Int, sessionRecord.lastHeartbeatTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["as"] as! String, sessionRecord.state)
        XCTAssertEqual(sessionInfo["sn"] as! Int, 10)
        XCTAssertEqual(sessionInfo["tr"] as! Bool, false)
        XCTAssertEqual(sessionInfo["ce"] as! Bool, true)
        XCTAssertEqual(sessionInfo["cs"] as! Bool, true)
        XCTAssertEqual(sessionInfo["sp"] as! [String: String], ["foo": "bar"])
    }

    func test_appInfoKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockMetadataFetcher(metadata: mockAppInfoResources)

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let appInfo = json["a"] as! [String: Any]
        XCTAssertNotNil(appInfo["bi"] as! String)
        XCTAssertNotNil(appInfo["bid"] as! String)
        XCTAssertEqual(appInfo["bv"] as! String, "fake_bundle_version")
        XCTAssertEqual(appInfo["e"] as! String, "fake_environment")
        XCTAssertEqual(appInfo["ed"] as! String, "fake_detailed_environment")
        XCTAssertEqual(appInfo["f"] as! Int, 1)
        XCTAssertEqual(appInfo["lc"] as! Int, 2)
        XCTAssertEqual(appInfo["sdk"] as! String, "fake_sdk_version")
        XCTAssertEqual(appInfo["v"] as! String, "fake_app_version")
    }

    func test_deviceInfoKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockMetadataFetcher(metadata: mockDeviceInfoResources)

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let deviceInfo = json["d"] as! [String: Any]
        XCTAssertEqual(deviceInfo["jb"] as! Bool, false)
        XCTAssertEqual(deviceInfo["lc"] as! String, "fake_locale")
        XCTAssertEqual(deviceInfo["tz"] as! String, "fake_timezone")
        XCTAssertEqual(deviceInfo["ms"] as! Int, 123456)
        XCTAssertEqual(deviceInfo["ov"] as! String, "fake_os_version")
        XCTAssertEqual(deviceInfo["ob"] as! String, "fake_os_build")
        XCTAssertEqual(deviceInfo["os"] as! String, "fake_os_type")
        XCTAssertEqual(deviceInfo["oa"] as! String, "fake_os_variant")
        XCTAssertEqual(deviceInfo["da"] as! String, "fake_architecture")
        XCTAssertEqual(deviceInfo["do"] as! String, "fake_model")
        XCTAssertEqual(deviceInfo["dm"] as! String, "fake_manufacturer")
        XCTAssertEqual(deviceInfo["sr"] as! String, "fake_screen_resolution")
    }
}

// swiftlint:enable force_cast line_length
