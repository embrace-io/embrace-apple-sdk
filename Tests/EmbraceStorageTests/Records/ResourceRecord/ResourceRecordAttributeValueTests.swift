//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceStorage
import OpenTelemetryApi

final class ResourceRecordAttributeValueTests: XCTestCase {

    func record(value: AttributeValue) -> ResourceRecord {
        return ResourceRecord(key: "example", value: value, resourceType: .permanent, resourceTypeId: "")
    }

    func test_bool_value() throws {
        let record = record(value: .bool(true))
        XCTAssertEqual(record.value, .bool(true))

        XCTAssertTrue(record.boolValue!)
        XCTAssertEqual(record.integerValue, 1)
        XCTAssertEqual(record.doubleValue, Double(1))
        XCTAssertEqual(record.stringValue, "true")
        XCTAssertNil(record.uuidValue)
    }

    func test_bool_value_when_false() throws {
        let record = record(value: .bool(false))
        XCTAssertEqual(record.value, .bool(false))

        XCTAssertFalse(record.boolValue!)
        XCTAssertEqual(record.integerValue, 0)
        XCTAssertEqual(record.doubleValue, Double(0))
        XCTAssertEqual(record.stringValue, "false")
        XCTAssertNil(record.uuidValue)
    }

    func test_integer_value() throws {
        let record = record(value: .int(42))
        XCTAssertEqual(record.value, .int(42))

        XCTAssertTrue(record.boolValue!)
        XCTAssertEqual(record.integerValue, 42)
        XCTAssertEqual(record.stringValue, "42")
        XCTAssertEqual(record.doubleValue, Double(42))
        XCTAssertNil(record.uuidValue)
    }

    func test_integer_value_when_0() throws {
        let record = record(value: .int(0))
        XCTAssertEqual(record.value, .int(0))

        XCTAssertFalse(record.boolValue!)
        XCTAssertEqual(record.integerValue, 0)
        XCTAssertEqual(record.doubleValue, Double(0))
        XCTAssertEqual(record.stringValue, "0")
        XCTAssertNil(record.uuidValue)
    }

    func test_integer_value_when_negative() throws {
        let record = record(value: .int(-42))
        XCTAssertEqual(record.value, .int(-42))

        XCTAssertFalse(record.boolValue!)
        XCTAssertEqual(record.integerValue, -42)
        XCTAssertEqual(record.doubleValue, Double(-42))
        XCTAssertEqual(record.stringValue, "-42")
        XCTAssertNil(record.uuidValue)
    }

    func test_double_value() throws {
        let record = record(value: .double(42.2))
        XCTAssertEqual(record.value, .double(42.2))

        XCTAssertTrue(record.boolValue!)
        XCTAssertEqual(record.integerValue, 42)
        XCTAssertEqual(record.doubleValue, Double(42.2))
        XCTAssertEqual(record.stringValue, "42.2")
        XCTAssertNil(record.uuidValue)
    }

    func test_double_value_when_0() throws {
        let record = record(value: .double(0))
        XCTAssertEqual(record.value, .double(0))

        XCTAssertFalse(record.boolValue!)
        XCTAssertEqual(record.integerValue, 0)
        XCTAssertEqual(record.doubleValue, Double(0))
        XCTAssertEqual(record.stringValue, "0.0")
        XCTAssertNil(record.uuidValue)
    }

    func test_double_value_when_negative() throws {
        let record = record(value: .double(-42.2))
        XCTAssertEqual(record.value, .double(-42.2))

        XCTAssertFalse(record.boolValue!)
        XCTAssertEqual(record.integerValue, -42)
        XCTAssertEqual(record.doubleValue, Double(-42.2))
        XCTAssertEqual(record.stringValue, "-42.2")
        XCTAssertNil(record.uuidValue)
    }

    func test_string_value() throws {
        let record = record(value: .string("value"))
        XCTAssertEqual(record.value, .string("value"))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertEqual(record.stringValue, "value")
        XCTAssertNil(record.uuidValue)
    }

    func test_string_value_when_numeric() throws {
        let record = record(value: .string("42.2"))
        XCTAssertEqual(record.value, .string("42.2"))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertEqual(record.doubleValue, 42.2)
        XCTAssertEqual(record.stringValue, "42.2")
        XCTAssertNil(record.uuidValue)
    }

    func test_string_value_when_boolean() throws {
        let record = record(value: .string("false"))
        XCTAssertEqual(record.value, .string("false"))

        XCTAssertFalse(record.boolValue!)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertEqual(record.stringValue, "false")
        XCTAssertNil(record.uuidValue)
    }

    func test_uuid_value() throws {
        let record = record(value: .string("53917E47-EA64-46AF-B6D9-B80D8677AB8B"))
        XCTAssertEqual(record.value, .string("53917E47-EA64-46AF-B6D9-B80D8677AB8B"))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertEqual(record.stringValue, "53917E47-EA64-46AF-B6D9-B80D8677AB8B")
        XCTAssertEqual(record.uuidValue, UUID(uuidString: "53917E47-EA64-46AF-B6D9-B80D8677AB8B"))
    }

    func test_boolArray_value() throws {
        let record = record(value: .boolArray([false, true]))
        XCTAssertEqual(record.value, .boolArray([false, true]))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertNil(record.stringValue)
        XCTAssertNil(record.uuidValue)
    }

    func test_intArray_value() throws {
        let record = record(value: .intArray([0, 1, 2]))
        XCTAssertEqual(record.value, .intArray([0, 1, 2]))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertNil(record.stringValue)
        XCTAssertNil(record.uuidValue)
    }

    func test_doubleArray_value() throws {
        let record = record(value: .doubleArray([0.2, 1.3, 2.4]))
        XCTAssertEqual(record.value, .doubleArray([0.2, 1.3, 2.4]))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertNil(record.stringValue)
        XCTAssertNil(record.uuidValue)
    }

    func test_stringArray_value() throws {
        let record = record(value: .stringArray(["foo", "bar"]))
        XCTAssertEqual(record.value, .stringArray(["foo", "bar"]))

        XCTAssertNil(record.boolValue)
        XCTAssertNil(record.integerValue)
        XCTAssertNil(record.doubleValue)
        XCTAssertNil(record.stringValue)
        XCTAssertNil(record.uuidValue)
    }
}
