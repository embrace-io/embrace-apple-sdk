//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceStorage
import EmbraceCommon

@testable import EmbraceCore

class LogPayloadBuilderTests: XCTestCase {
    func test_build_addsLogIdAttribute() throws {
        let logId = LogIdentifier(value: try XCTUnwrap(UUID(uuidString: "53B55EDD-889A-4876-86BA-6798288B609C")))
        let record = LogRecord(identifier: logId,
                               processIdentifier: .random,
                               severity: .info,
                               body: "Hello World",
                               attributes: .empty())

        let payload = LogPayloadBuilder.build(log: record)

        let attribute = payload.attributes.first(where: { $0.key == "log.record.uid"})
        XCTAssertNotNil(attribute)
        XCTAssertEqual(attribute?.value, logId.toString)
    }

    func test_buildLogRecordWithAttributes_mapsKeyValuesAsAttributeStruct() {
        let originalAttributes: [String: PersistableValue] = [
            "string_attribute": .string("string"),
            "integer_attribute": .int(1),
            "boolean_attribute": .bool(false),
            "double_attribute": .double(5.0)
        ]
        let record = LogRecord(identifier: .random,
                               processIdentifier: .random,
                               severity: .info,
                               body: .random(),
                               attributes: originalAttributes)

        let payload = LogPayloadBuilder.build(log: record)

        XCTAssertGreaterThanOrEqual(payload.attributes.count, originalAttributes.count)
        originalAttributes.forEach { originalAttributeKey, originalAttributeValue in
            let originalAttributeWasMigrated = payload.attributes.contains { attribute in
                attribute.key == originalAttributeKey && attribute.value == originalAttributeValue.description
            }
            XCTAssertTrue(originalAttributeWasMigrated)
        }
    }
}
