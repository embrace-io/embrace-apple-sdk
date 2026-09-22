//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class LogPayloadBuilderTests: XCTestCase {
    func test_build_addsLogIdAttribute() throws {
        let logId = EmbraceIdentifier.random
        let record = MockLog(
            id: logId.stringValue
        )

        let payload = LogPayloadBuilder.build(log: record)

        let attribute = payload.attributes.first(where: { $0.key == "log.record.uid" })
        XCTAssertNotNil(attribute)
        XCTAssertEqual(attribute?.value, logId.stringValue)
    }

    func test_buildLogRecordWithAttributes_mapsKeyValuesAsAttributeStruct() {
        let originalAttributes: [String: String] = [
            "string_attribute": "string",
            "integer_attribute": "1",
            "boolean_attribute": "false",
            "double_attribute": "5.0"
        ]
        let record = MockLog(
            attributes: originalAttributes
        )

        let payload = LogPayloadBuilder.build(log: record)

        XCTAssertGreaterThanOrEqual(payload.attributes.count, originalAttributes.count)

        for (key, value) in originalAttributes {
            let attribute = payload.attributes.first(where: { $0.key == key && $0.value == value.description })
            XCTAssertNotNil(attribute)
        }
    }

    func test_manualBuild() throws {
        // given a session in storage
        let storage = try EmbraceStorage.createInMemoryDb()
        storage.addSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60),
            userSessionId: TestConstants.userSessionId
        )

        // given metadata in storage of that user session
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.0.0",
            type: .requiredResource,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: UserResourceKey.identifier.rawValue,
            value: "test",
            type: .customProperty,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )
        storage.addMetadata(
            key: "tag1",
            value: "tag1",
            type: .personaTag,
            lifespan: .permanent
        )
        storage.addMetadata(
            key: "tag2",
            value: "tag2",
            type: .personaTag,
            lifespan: .userSession,
            lifespanId: TestConstants.userSessionId.stringValue
        )

        // when manually building a log payload
        let timestamp = Date(timeIntervalSince1970: 30)
        let payload = LogPayloadBuilder.build(
            timestamp: timestamp,
            severity: .fatal,
            body: "test",
            attributes: [
                "key1": "value1",
                "key2": "value2"
            ],
            storage: storage,
            userSessionId: TestConstants.userSessionId,
            processId: TestConstants.processId
        )

        // then the payload is correct
        XCTAssertEqual(payload.resource.appVersion, "1.0.0")
        XCTAssertEqual(payload.metadata.userId, "test")
        XCTAssertEqual(payload.metadata.personas, ["tag1", "tag2"])

        let logs = try XCTUnwrap(payload.data["logs"])
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].body, "test")
        XCTAssertEqual(logs[0].timeUnixNano, String(timestamp.nanosecondsSince1970Truncated))
        XCTAssertEqual(logs[0].severityNumber, EmbraceLogSeverity.fatal.rawValue)
        XCTAssertEqual(logs[0].severityText, EmbraceLogSeverity.fatal.name)

        let attribute1 = logs[0].attributes.first { $0.key == "key1" }
        XCTAssertEqual(attribute1!.value, "value1")

        let attribute2 = logs[0].attributes.first { $0.key == "key2" }
        XCTAssertEqual(attribute2!.value, "value2")
    }
    /// Experiments are stored as a required resource so a later process can read them back, but they
    /// are reported as an attribute of each log. They must never surface in the resource block.
    func test_manualBuild_experimentsAreNeverAResource() throws {
        // given experiments stored for the current process
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        storage.addMetadata(
            key: LogSemantics.keyExperiments,
            value: "e:exp::1000000",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when manually building a log payload
        let payload = LogPayloadBuilder.build(
            timestamp: Date(timeIntervalSince1970: 30),
            severity: .fatal,
            body: "test",
            attributes: [:],
            storage: storage,
            userSessionId: nil,
            processId: ProcessIdentifier.current
        )

        // then the experiments are absent from the resource, in the struct and in the encoded json
        let jsonData = try JSONEncoder().encode(payload)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])
        let resource = try XCTUnwrap(json["resource"] as? [String: Any])

        XCTAssertNil(payload.resource.additionalResources[LogSemantics.keyExperiments])
        XCTAssertNil(resource[LogSemantics.keyExperiments])
    }

    func test_manualBuild_sessionFromAnotherProcess() throws {
        // given a session part in storage that belongs to a previous process
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let previousProcessId = EmbraceIdentifier.random
        let userSessionId = EmbraceIdentifier.random

        storage.addSession(
            id: TestConstants.sessionId,
            processId: previousProcessId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60),
            userSessionId: userSessionId
        )

        // given a process scoped resource stored for that process and for the current one
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.0.0",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: previousProcessId.stringValue
        )
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "2.0.0",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when manually building a log payload for that user session and its process
        let payload = LogPayloadBuilder.build(
            timestamp: Date(timeIntervalSince1970: 30),
            severity: .fatal,
            body: "test",
            attributes: [:],
            storage: storage,
            userSessionId: userSessionId,
            processId: previousProcessId
        )

        // then the payload describes the session's process, not the one building it
        XCTAssertEqual(payload.resource.appVersion, "1.0.0")
    }

    /// A log whose process can't be determined goes without process-scoped resources. Falling back
    /// to the current process would report this launch's resources as if they belonged to another.
    func test_manualBuild_withoutProcessId_reportsNoProcessResources() throws {
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        // given a process scoped resource stored for the current process
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.0.0",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when manually building a log payload with no session and no process
        let payload = LogPayloadBuilder.build(
            timestamp: Date(timeIntervalSince1970: 30),
            severity: .fatal,
            body: "test",
            attributes: [:],
            storage: storage,
            userSessionId: nil,
            processId: nil
        )

        // then the current process's resources are not borrowed
        XCTAssertNil(payload.resource.appVersion)
    }

    func test_manualBuild_withProcessId() throws {
        // given a process scoped resource stored for two different processes
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        let previousProcessId = EmbraceIdentifier.random

        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "1.0.0",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: previousProcessId.stringValue
        )
        storage.addMetadata(
            key: AppResourceKey.appVersion.rawValue,
            value: "2.0.0",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when manually building a log payload for a given process and no session
        let payload = LogPayloadBuilder.build(
            timestamp: Date(timeIntervalSince1970: 30),
            severity: .fatal,
            body: "test",
            attributes: [:],
            storage: storage,
            userSessionId: nil,
            processId: previousProcessId
        )

        // then the payload describes that process
        XCTAssertEqual(payload.resource.appVersion, "1.0.0")
    }
}
