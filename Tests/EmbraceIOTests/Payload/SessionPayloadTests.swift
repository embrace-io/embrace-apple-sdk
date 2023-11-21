//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
@testable import EmbraceStorage
@testable import EmbraceCommon

// swiftlint:disable force_try force_cast
final class SessionPayloadTests: XCTestCase {
    let options = EmbraceStorage.Options(baseUrl: URL(fileURLWithPath: NSTemporaryDirectory()), fileName: "test.sqlite")

    var mockSessionRecord: SessionRecord {
        .init(id: "1234", state: .foreground, processId: UUID(), startTime: Date(timeIntervalSince1970: 10), endTime: Date(timeIntervalSince1970: 40))
    }

    var mockResources: [ResourceRecord] = [.init(key: AppResourceKeys.buildUUID.rawValue, value: "fake_uuid", resourceType: .process),
                                           .init(key: AppResourceKeys.bundleVersion.rawValue, value: "fake_bundle_version", resourceType: .process),
                                           .init(key: AppResourceKeys.environment.rawValue, value: "fake_environment", resourceType: .process),
                                           .init(key: AppResourceKeys.detailedEnvironment.rawValue, value: "fake_detailed_environment", resourceType: .process),
                                           .init(key: AppResourceKeys.framework.rawValue, value: String(1), resourceType: .process),
                                           .init(key: AppResourceKeys.launchCount.rawValue, value: String(2), resourceType: .process),
                                           .init(key: AppResourceKeys.sdkVersion.rawValue, value: "fake_sdk_version", resourceType: .process),
                                           .init(key: AppResourceKeys.appVersion.rawValue, value: "fake_app_version", resourceType: .process)]

    func test_properties() {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockResourceFetcher(resources: [])

        // when creating a payload
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher)

        // then the properties are correctly set
        XCTAssertEqual(payload.messageFormatVersion, 15)
        XCTAssertEqual(payload.sessionInfo.sessionId, sessionRecord.id)
        XCTAssertEqual(payload.sessionInfo.startTime, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.endTime, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(payload.sessionInfo.appState, sessionRecord.state)
    }

    func test_highLevelKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let fetcher = MockResourceFetcher(resources: [])

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
        let fetcher = MockResourceFetcher(resources: [])

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let sessionInfo = json["s"] as! [String: Any]
        XCTAssertEqual(sessionInfo["id"] as! String, sessionRecord.id)
        XCTAssertEqual(sessionInfo["st"] as! Int, sessionRecord.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["et"] as? Int, sessionRecord.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfo["as"] as! String, sessionRecord.state)
    }

    func test_appInfoKeys() throws {
        // given a session record
        let sessionRecord = mockSessionRecord
        let mockResources: [ResourceRecord] = [.init(key: AppResourceKeys.buildUUID.rawValue, value: "fake_uuid", resourceType: .process),
                                               .init(key: AppResourceKeys.bundleVersion.rawValue, value: "fake_bundle_version", resourceType: .process),
                                               .init(key: AppResourceKeys.environment.rawValue, value: "fake_environment", resourceType: .process),
                                               .init(key: AppResourceKeys.detailedEnvironment.rawValue, value: "fake_detailed_environment", resourceType: .process),
                                               .init(key: AppResourceKeys.framework.rawValue, value: String(1), resourceType: .process),
                                               .init(key: AppResourceKeys.launchCount.rawValue, value: String(2), resourceType: .process),
                                               .init(key: AppResourceKeys.sdkVersion.rawValue, value: "fake_sdk_version", resourceType: .process),
                                               .init(key: AppResourceKeys.appVersion.rawValue, value: "fake_app_version", resourceType: .process)]
        let fetcher = MockResourceFetcher(resources: mockResources)

        // when serializing
        let payload = SessionPayload(from: sessionRecord, resourceFetcher: fetcher)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the session payload contains the necessary keys
        let appInfo = json["a"] as! [String: Any]
        XCTAssertEqual(appInfo["bi"] as! String, "fake_uuid")
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
        let mockResources: [ResourceRecord] = [.init(key: DeviceResourceKeys.isJailbroken.rawValue, value: String(false), resourceType: .process),
                                               .init(key: DeviceResourceKeys.locale.rawValue, value: "fake_locale", resourceType: .process),
                                               .init(key: DeviceResourceKeys.timezone.rawValue, value: "fake_timezone", resourceType: .process),
                                               .init(key: DeviceResourceKeys.totalDiskSpace.rawValue, value: String(123456), resourceType: .process),
                                               .init(key: DeviceResourceKeys.OSVersion.rawValue, value: "fake_os_version", resourceType: .process),
                                               .init(key: DeviceResourceKeys.OSBuild.rawValue, value: "fake_os_build", resourceType: .process)]
        let fetcher = MockResourceFetcher(resources: mockResources)

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
    }
}
// swiftlint:enable force_try force_cast
