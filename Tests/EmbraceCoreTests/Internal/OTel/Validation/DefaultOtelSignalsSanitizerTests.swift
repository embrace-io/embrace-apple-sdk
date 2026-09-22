//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import XCTest

@testable import EmbraceCore

class DefaultOtelSignalsSanitizerTests: XCTestCase {

    func test_sanitizeSpanName() throws {
        // given a sanitizer with a limit of 5 characters for span names
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(nameLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing a span name
        let spanName = sanitizer.sanitizeSpanName("   123456789    ")

        // then the name gets correctly sanitized
        XCTAssertEqual(spanName, "12345")
    }

    func test_sanitizeSpanEventName() throws {
        // given a sanitizer with a limit of 5 characters for span event names
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(nameLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing a span event name
        let spanEventName = sanitizer.sanitizeSpanEventName("   123456789    ")

        // then the name gets correctly sanitized
        XCTAssertEqual(spanEventName, "12345")
    }

    func test_sanitizeAttributeKey() throws {
        // given a sanitizer with a limit of 5 characters for attribute keys
        let attributeLimits = AttributeLimits(keyLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)

        // when sanitizing an attribute key
        let attributeKey = sanitizer.sanitizeAttributeKey("123456789")

        // then the key gets correctly sanitized
        XCTAssertEqual(attributeKey, "12345")
    }

    func test_sanitizeAttributeValue() throws {
        // given a sanitizer with a limit of 5 characters for attribute values
        let attributeLimits = AttributeLimits(valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)

        // when sanitizing an attribute value
        let attributeValue = sanitizer.sanitizeAttributeValue("123456789")

        // then the value gets correctly sanitized
        XCTAssertEqual(attributeValue as! String, "12345")
    }

    let testAttributes: [String: String] = [
        "123": "123",
        "123456789": "123456789",
        "test": "test"
    ]

    func test_sanitizeSpanAttributes() throws {
        // given a sanitizer with
        //   - a limit of 2 attributes per span
        //   - a limit of 5 characters for attribute keys
        //   - a limit of 5 characters for attribute values
        let spanLimits = SessionLimits.SpanLimits(attributeCount: 2)
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: SessionLimits(customSpans: spanLimits),
            attributeLimits: attributeLimits
        )

        // when sanitizing span attributes
        let attributes = sanitizer.sanitizeSpanAttributes(testAttributes)

        // then the attributes get correctly sanitized
        XCTAssertEqual(attributes.count, 2)
        XCTAssertEqual(attributes["123"] as! String, "123")
        XCTAssertEqual(attributes["12345"] as! String, "12345")
    }

    func test_sanitizeSpanEventAttributes() throws {
        // given a sanitizer with
        //   - a limit of 2 attributes per span event
        //   - a limit of 5 characters for attribute keys
        //   - a limit of 5 characters for attribute values
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(attributeCount: 2))
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: limits,
            attributeLimits: attributeLimits
        )

        // when sanitizing span event attributes
        let attributes = sanitizer.sanitizeSpanEventAttributes(testAttributes)

        // then the attributes get correctly sanitized
        XCTAssertEqual(attributes.count, 2)
        XCTAssertEqual(attributes["123"] as! String, "123")
        XCTAssertEqual(attributes["12345"] as! String, "12345")
    }

    func test_sanitizeSpanLinkAttributes() throws {
        // given a sanitizer with
        //   - a limit of 2 attributes per span link
        //   - a limit of 5 characters for attribute keys
        //   - a limit of 5 characters for attribute values
        let limits = SessionLimits(links: SessionLimits.SpanLinkLimits(attributeCount: 2))
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: limits,
            attributeLimits: attributeLimits
        )

        // when sanitizing span link attributes
        let attributes = sanitizer.sanitizeSpanLinkAttributes(testAttributes)

        // then the attributes get correctly sanitized
        XCTAssertEqual(attributes.count, 2)
        XCTAssertEqual(attributes["123"] as! String, "123")
        XCTAssertEqual(attributes["12345"] as! String, "12345")
    }

    func test_sanitizeLogAttributes() throws {
        // given a sanitizer with
        //   - a limit of 2 attributes per log
        //   - a limit of 5 characters for attribute keys
        //   - a limit of 5 characters for attribute values
        let limits = SessionLimits(logs: SessionLimits.LogLimits(attributeCount: 2))
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: limits,
            attributeLimits: attributeLimits
        )

        // when sanitizing log attributes
        let attributes = sanitizer.sanitizeLogAttributes(testAttributes)

        // then the attributes get correctly sanitized
        XCTAssertEqual(attributes.count, 2)
        XCTAssertEqual(attributes["123"] as! String, "123")
        XCTAssertEqual(attributes["12345"] as! String, "12345")
    }

    func test_sanitizeSpanAttributes_protecting() throws {
        // given a sanitizer with a limit of 2 span attributes
        // and a set of 3 attributes where one is protected
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(attributeCount: 2))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: [String: String] = [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            "protected": "keep"  // protected key
        ]

        // when sanitizing with a protected key set
        let result = sanitizer.sanitizeSpanAttributes(attributes, protecting: ["protected"])

        // then the protected key is always present regardless of the count limit
        XCTAssertEqual(result["protected"] as! String, "keep")
        // and the non-protected attributes are still capped at 2
        let nonProtectedCount = result.keys.filter { $0 != "protected" }.count
        XCTAssertEqual(nonProtectedCount, 2)
        XCTAssertNil(result["ccc"])
    }

    func test_sanitizeSpanAttributes_protecting_emptySet() throws {
        // given a sanitizer with a limit of 2 span attributes and no protected keys
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(attributeCount: 2))
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits, attributeLimits: attributeLimits)

        // when sanitizing with an empty protected key set
        let result = sanitizer.sanitizeSpanAttributes(testAttributes, protecting: [])

        // then it behaves identically to the no-protecting overload
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["123"] as! String, "123")
        XCTAssertEqual(result["12345"] as! String, "12345")
    }

    func test_sanitizeLogAttributes_protecting() throws {
        // given a sanitizer with a limit of 2 log attributes
        // and a set of 3 attributes where one is protected
        let limits = SessionLimits(logs: SessionLimits.LogLimits(attributeCount: 2))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: [String: String] = [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            "protected": "keep"  // protected key
        ]

        // when sanitizing with a protected key set
        let result = sanitizer.sanitizeLogAttributes(attributes, protecting: ["protected"])

        // then the protected key is always present regardless of the count limit
        XCTAssertEqual(result["protected"] as! String, "keep")
        // and the non-protected attributes are still capped at 2
        let nonProtectedCount = result.keys.filter { $0 != "protected" }.count
        XCTAssertEqual(nonProtectedCount, 2)
        XCTAssertNil(result["ccc"])
    }

    func test_sanitizeLogAttributes_protecting_emptySet() throws {
        // given a sanitizer with a limit of 2 log attributes and no protected keys
        let limits = SessionLimits(logs: SessionLimits.LogLimits(attributeCount: 2))
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits, attributeLimits: attributeLimits)

        // when sanitizing with an empty protected key set
        let result = sanitizer.sanitizeLogAttributes(testAttributes, protecting: [])

        // then it behaves identically to the no-protecting overload
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["123"] as! String, "123")
        XCTAssertEqual(result["12345"] as! String, "12345")
    }

    func test_sanitizeSpanEventAttributes_protecting() throws {
        // given a sanitizer with a limit of 2 span event attributes
        // and a set of 3 attributes where one is protected
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(attributeCount: 2))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: [String: String] = [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            "protected": "keep"  // protected key
        ]

        // when sanitizing with a protected key set
        let result = sanitizer.sanitizeSpanEventAttributes(attributes, protecting: ["protected"])

        // then the protected key is always present regardless of the count limit
        XCTAssertEqual(result["protected"] as! String, "keep")
        // and the non-protected attributes are still capped at 2
        let nonProtectedCount = result.keys.filter { $0 != "protected" }.count
        XCTAssertEqual(nonProtectedCount, 2)
        XCTAssertNil(result["ccc"])
    }

    func test_sanitizeSpanEventAttributes_protecting_emptySet() throws {
        // given a sanitizer with a limit of 2 span event attributes and no protected keys
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(attributeCount: 2))
        let attributeLimits = AttributeLimits(keyLength: 5, valueLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits, attributeLimits: attributeLimits)

        // when sanitizing with an empty protected key set
        let result = sanitizer.sanitizeSpanEventAttributes(testAttributes, protecting: [])

        // then it behaves identically to the no-protecting overload
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["123"] as! String, "123")
        XCTAssertEqual(result["12345"] as! String, "12345")
    }

    // MARK: - Non-string attribute values

    /// Attribute values are not required to be strings: `EmbraceAttributeValue` also covers
    /// booleans, all integer widths, `Float` and `Double`. All of them must survive sanitization.
    let mixedTypeAttributes: EmbraceAttributes = [
        "string": "text",
        "bool": true,
        "int": 42,
        "int64": Int64(9_000_000_000),
        "uint8": UInt8(255),
        "float": Float(1.5),
        "double": 2.5
    ]

    func test_sanitizeSpanAttributes_keepsNonStringValues() throws {
        // given a sanitizer with a limit high enough to fit every attribute
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(attributeCount: 100))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing attributes of mixed value types
        let result = sanitizer.sanitizeSpanAttributes(mixedTypeAttributes)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["string"] as? String, "text")
        XCTAssertEqual(result["bool"] as? Bool, true)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["int64"] as? Int64, 9_000_000_000)
        XCTAssertEqual(result["uint8"] as? UInt8, 255)
        XCTAssertEqual(result["float"] as? Float, 1.5)
        XCTAssertEqual(result["double"] as? Double, 2.5)
    }

    func test_sanitizeLogAttributes_keepsNonStringValues() throws {
        // given a sanitizer with a limit high enough to fit every attribute
        let limits = SessionLimits(logs: SessionLimits.LogLimits(attributeCount: 100))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing log attributes of mixed value types
        let result = sanitizer.sanitizeLogAttributes(mixedTypeAttributes)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["bool"] as? Bool, true)
        XCTAssertEqual(result["double"] as? Double, 2.5)
    }

    func test_sanitizeSpanEventAttributes_keepsNonStringValues() throws {
        // given a sanitizer with a limit high enough to fit every attribute
        let limits = SessionLimits(events: SessionLimits.SpanEventLimits(attributeCount: 100))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing span event attributes of mixed value types
        let result = sanitizer.sanitizeSpanEventAttributes(mixedTypeAttributes)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["bool"] as? Bool, true)
    }

    func test_sanitizeSpanLinkAttributes_keepsNonStringValues() throws {
        // given a sanitizer with a limit high enough to fit every attribute
        let limits = SessionLimits(links: SessionLimits.SpanLinkLimits(attributeCount: 100))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing span link attributes of mixed value types
        let result = sanitizer.sanitizeSpanLinkAttributes(mixedTypeAttributes)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["bool"] as? Bool, true)
    }

    func test_sanitizeAttributes_doesNotTruncateNonStringValues() throws {
        // given a sanitizer with a value length limit shorter than the
        // string representation of the numeric values being sanitized
        let attributeLimits = AttributeLimits(valueLength: 2)
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)
        let attributes: EmbraceAttributes = [
            "int": 123_456_789,
            "double": 3.14159,
            "string": "123456789"
        ]

        // when sanitizing the attributes
        let result = sanitizer.sanitizeSpanAttributes(attributes)

        // then only the string value is truncated; the rest are kept whole
        XCTAssertEqual(result["int"] as? Int, 123_456_789)
        XCTAssertEqual(result["double"] as? Double, 3.14159)
        XCTAssertEqual(result["string"] as? String, "12")
    }

    func test_sanitizeAttributes_truncatesKeysOfNonStringValues() throws {
        // given a sanitizer with a limit of 5 characters for attribute keys
        let attributeLimits = AttributeLimits(keyLength: 5)
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)
        let attributes: EmbraceAttributes = ["123456789": 42]

        // when sanitizing the attributes
        let result = sanitizer.sanitizeSpanAttributes(attributes)

        // then the key is truncated and the value is kept untouched
        XCTAssertEqual(result["12345"] as? Int, 42)
        XCTAssertNil(result["123456789"])
    }

    func test_sanitizeAttributes_nonStringValuesCountTowardsLimit() throws {
        // given a sanitizer with a limit of 2 span attributes
        let limits = SessionLimits(customSpans: SessionLimits.SpanLimits(attributeCount: 2))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: EmbraceAttributes = [
            "aaa": 1,
            "bbb": true,
            "ccc": "3"
        ]

        // when sanitizing the attributes
        let result = sanitizer.sanitizeSpanAttributes(attributes)

        // then non-string values consume the attribute budget just like strings do,
        // and keys are dropped in sorted order once the limit is hit
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["aaa"] as? Int, 1)
        XCTAssertEqual(result["bbb"] as? Bool, true)
        XCTAssertNil(result["ccc"])
    }
}
