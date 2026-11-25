//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import XCTest

@testable import EmbraceCore

class DefaultOtelSignalsSanitizerTests: XCTestCase {

    func test_sanitizeSpanName() throws {
        // given a sanitizer with a limit of 5 characters for span names
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(nameLength: 5)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing a span name
        let spanName = sanitizer.sanitizeSpanName("   123456789    ", source: .user)

        // then the name gets correctly sanitized
        XCTAssertEqual(spanName, "12345")
    }

    func test_sanitizeSpanEventName() throws {
        // given a sanitizer with a limit of 5 characters for span event names
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(nameLength: 5)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing a span event name
        let spanEventName = sanitizer.sanitizeSpanEventName("   123456789    ", source: .user)

        // then the name gets correctly sanitized
        XCTAssertEqual(spanEventName, "12345")
    }

    func test_sanitizeAttributeKey() throws {
        // given a sanitizer with a limit of 5 characters for attribute keys
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)

        // when sanitizing an attribute key
        let attributeKey = sanitizer.sanitizeAttributeKey("123456789", source: .user)

        // then the key gets correctly sanitized
        XCTAssertEqual(attributeKey, "12345")
    }

    func test_sanitizeAttributeValue() throws {
        // given a sanitizer with a limit of 5 characters for attribute values
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)

        // when sanitizing an attribute value
        let attributeValue = sanitizer.sanitizeAttributeValue("123456789", source: .user)

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
        let spanLimits = SignalLimits.SpanLimits(attributeCount: 2)
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: SessionLimits(user: SignalLimits(customSpans: spanLimits)),
            attributeLimits: attributeLimits
        )

        // when sanitizing span attributes
        let attributes = sanitizer.sanitizeSpanAttributes(testAttributes, source: .user)

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
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(attributeCount: 2)))
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: limits,
            attributeLimits: attributeLimits
        )

        // when sanitizing span event attributes
        let attributes = sanitizer.sanitizeSpanEventAttributes(testAttributes, source: .user)

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
        let limits = SessionLimits(user: SignalLimits(links: SignalLimits.SpanLinkLimits(attributeCount: 2)))
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: limits,
            attributeLimits: attributeLimits
        )

        // when sanitizing span link attributes
        let attributes = sanitizer.sanitizeSpanLinkAttributes(testAttributes, source: .user)

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
        let limits = SessionLimits(user: SignalLimits(logs: SignalLimits.LogLimits(attributeCount: 2)))
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: limits,
            attributeLimits: attributeLimits
        )

        // when sanitizing log attributes
        let attributes = sanitizer.sanitizeLogAttributes(testAttributes, source: .user)

        // then the attributes get correctly sanitized
        XCTAssertEqual(attributes.count, 2)
        XCTAssertEqual(attributes["123"] as! String, "123")
        XCTAssertEqual(attributes["12345"] as! String, "12345")
    }

    func test_sanitizeSpanAttributes_protecting() throws {
        // given a sanitizer with a limit of 2 span attributes
        // and a set of 3 attributes where one is protected
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 2)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: [String: String] = [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            "protected": "keep"  // protected key
        ]

        // when sanitizing with a protected key set
        let result = sanitizer.sanitizeSpanAttributes(attributes, protecting: ["protected"], source: .user)

        // then the protected key is always present regardless of the count limit
        XCTAssertEqual(result["protected"] as! String, "keep")
        // and the non-protected attributes are still capped at 2
        let nonProtectedCount = result.keys.filter { $0 != "protected" }.count
        XCTAssertEqual(nonProtectedCount, 2)
        XCTAssertNil(result["ccc"])
    }

    func test_sanitizeSpanAttributes_protecting_emptySet() throws {
        // given a sanitizer with a limit of 2 span attributes and no protected keys
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 2)))
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits, attributeLimits: attributeLimits)

        // when sanitizing with an empty protected key set
        let result = sanitizer.sanitizeSpanAttributes(testAttributes, protecting: [], source: .user)

        // then it behaves identically to the no-protecting overload
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["123"] as! String, "123")
        XCTAssertEqual(result["12345"] as! String, "12345")
    }

    func test_sanitizeLogAttributes_protecting() throws {
        // given a sanitizer with a limit of 2 log attributes
        // and a set of 3 attributes where one is protected
        let limits = SessionLimits(user: SignalLimits(logs: SignalLimits.LogLimits(attributeCount: 2)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: [String: String] = [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            "protected": "keep"  // protected key
        ]

        // when sanitizing with a protected key set
        let result = sanitizer.sanitizeLogAttributes(attributes, protecting: ["protected"], source: .user)

        // then the protected key is always present regardless of the count limit
        XCTAssertEqual(result["protected"] as! String, "keep")
        // and the non-protected attributes are still capped at 2
        let nonProtectedCount = result.keys.filter { $0 != "protected" }.count
        XCTAssertEqual(nonProtectedCount, 2)
        XCTAssertNil(result["ccc"])
    }

    func test_sanitizeLogAttributes_protecting_emptySet() throws {
        // given a sanitizer with a limit of 2 log attributes and no protected keys
        let limits = SessionLimits(user: SignalLimits(logs: SignalLimits.LogLimits(attributeCount: 2)))
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits, attributeLimits: attributeLimits)

        // when sanitizing with an empty protected key set
        let result = sanitizer.sanitizeLogAttributes(testAttributes, protecting: [], source: .user)

        // then it behaves identically to the no-protecting overload
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["123"] as! String, "123")
        XCTAssertEqual(result["12345"] as! String, "12345")
    }

    func test_sanitizeSpanEventAttributes_protecting() throws {
        // given a sanitizer with a limit of 2 span event attributes
        // and a set of 3 attributes where one is protected
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(attributeCount: 2)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: [String: String] = [
            "aaa": "1",
            "bbb": "2",
            "ccc": "3",  // would be dropped by count limit
            "protected": "keep"  // protected key
        ]

        // when sanitizing with a protected key set
        let result = sanitizer.sanitizeSpanEventAttributes(attributes, protecting: ["protected"], source: .user)

        // then the protected key is always present regardless of the count limit
        XCTAssertEqual(result["protected"] as! String, "keep")
        // and the non-protected attributes are still capped at 2
        let nonProtectedCount = result.keys.filter { $0 != "protected" }.count
        XCTAssertEqual(nonProtectedCount, 2)
        XCTAssertNil(result["ccc"])
    }

    func test_sanitizeSpanEventAttributes_protecting_emptySet() throws {
        // given a sanitizer with a limit of 2 span event attributes and no protected keys
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(attributeCount: 2)))
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5, valueLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits, attributeLimits: attributeLimits)

        // when sanitizing with an empty protected key set
        let result = sanitizer.sanitizeSpanEventAttributes(testAttributes, protecting: [], source: .user)

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
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 100)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing attributes of mixed value types
        let result = sanitizer.sanitizeSpanAttributes(mixedTypeAttributes, source: .user)

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
        let limits = SessionLimits(user: SignalLimits(logs: SignalLimits.LogLimits(attributeCount: 100)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing log attributes of mixed value types
        let result = sanitizer.sanitizeLogAttributes(mixedTypeAttributes, source: .user)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["bool"] as? Bool, true)
        XCTAssertEqual(result["double"] as? Double, 2.5)
    }

    func test_sanitizeSpanEventAttributes_keepsNonStringValues() throws {
        // given a sanitizer with a limit high enough to fit every attribute
        let limits = SessionLimits(user: SignalLimits(events: SignalLimits.SpanEventLimits(attributeCount: 100)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing span event attributes of mixed value types
        let result = sanitizer.sanitizeSpanEventAttributes(mixedTypeAttributes, source: .user)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["bool"] as? Bool, true)
    }

    func test_sanitizeSpanLinkAttributes_keepsNonStringValues() throws {
        // given a sanitizer with a limit high enough to fit every attribute
        let limits = SessionLimits(user: SignalLimits(links: SignalLimits.SpanLinkLimits(attributeCount: 100)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing span link attributes of mixed value types
        let result = sanitizer.sanitizeSpanLinkAttributes(mixedTypeAttributes, source: .user)

        // then every attribute is kept with its original type and value
        XCTAssertEqual(result.count, mixedTypeAttributes.count)
        XCTAssertEqual(result["int"] as? Int, 42)
        XCTAssertEqual(result["bool"] as? Bool, true)
    }

    func test_sanitizeAttributes_doesNotTruncateNonStringValues() throws {
        // given a sanitizer with a value length limit shorter than the
        // string representation of the numeric values being sanitized
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(valueLength: 2))
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)
        let attributes: EmbraceAttributes = [
            "int": 123_456_789,
            "double": 3.14159,
            "string": "123456789"
        ]

        // when sanitizing the attributes
        let result = sanitizer.sanitizeSpanAttributes(attributes, source: .user)

        // then only the string value is truncated; the rest are kept whole
        XCTAssertEqual(result["int"] as? Int, 123_456_789)
        XCTAssertEqual(result["double"] as? Double, 3.14159)
        XCTAssertEqual(result["string"] as? String, "12")
    }

    func test_sanitizeAttributes_truncatesKeysOfNonStringValues() throws {
        // given a sanitizer with a limit of 5 characters for attribute keys
        let attributeLimits = AttributeLimits(user: AttributeLengthLimits(keyLength: 5))
        let sanitizer = DefaultOtelSignalsSanitizer(attributeLimits: attributeLimits)
        let attributes: EmbraceAttributes = ["123456789": 42]

        // when sanitizing the attributes
        let result = sanitizer.sanitizeSpanAttributes(attributes, source: .user)

        // then the key is truncated and the value is kept untouched
        XCTAssertEqual(result["12345"] as? Int, 42)
        XCTAssertNil(result["123456789"])
    }

    func test_sanitizeAttributes_nonStringValuesCountTowardsLimit() throws {
        // given a sanitizer with a limit of 2 span attributes
        let limits = SessionLimits(user: SignalLimits(customSpans: SignalLimits.SpanLimits(attributeCount: 2)))
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)
        let attributes: EmbraceAttributes = [
            "aaa": 1,
            "bbb": true,
            "ccc": "3"
        ]

        // when sanitizing the attributes
        let result = sanitizer.sanitizeSpanAttributes(attributes, source: .user)

        // then non-string values consume the attribute budget just like strings do,
        // and keys are dropped in sorted order once the limit is hit
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["aaa"] as? Int, 1)
        XCTAssertEqual(result["bbb"] as? Bool, true)
        XCTAssertNil(result["ccc"])
    }

    // MARK: - Sources

    func test_captureService_namesAreNotTruncated() throws {
        // given a sanitizer with the default limits
        let sanitizer = DefaultOtelSignalsSanitizer()
        let longName = String(repeating: "a", count: 500)

        // when sanitizing names for capture services
        let spanName = sanitizer.sanitizeSpanName("  \(longName)  ", source: .captureService)
        let eventName = sanitizer.sanitizeSpanEventName("  \(longName)  ", source: .captureService)

        // then the names are trimmed but not truncated
        XCTAssertEqual(spanName, longName)
        XCTAssertEqual(eventName, longName)

        // and they are truncated for users
        XCTAssertEqual(sanitizer.sanitizeSpanName(longName, source: .user).count, 128)
        XCTAssertEqual(sanitizer.sanitizeSpanEventName(longName, source: .user).count, 128)
    }

    func test_captureService_attributesAreNotTruncated() throws {
        // given a sanitizer with the default limits
        let sanitizer = DefaultOtelSignalsSanitizer()
        let longKey = String(repeating: "k", count: 500)
        let longValue = String(repeating: "v", count: 5000)

        // when sanitizing a long attribute for capture services
        let key = sanitizer.sanitizeAttributeKey(longKey, source: .captureService)
        let value = sanitizer.sanitizeAttributeValue(longValue, source: .captureService)
        let spanAttributes = sanitizer.sanitizeSpanAttributes([longKey: longValue], source: .captureService)
        let eventAttributes = sanitizer.sanitizeSpanEventAttributes([longKey: longValue], source: .captureService)
        let linkAttributes = sanitizer.sanitizeSpanLinkAttributes([longKey: longValue], source: .captureService)
        let logAttributes = sanitizer.sanitizeLogAttributes([longKey: longValue], source: .captureService)

        // then nothing is truncated
        XCTAssertEqual(key, longKey)
        XCTAssertEqual(value as? String, longValue)
        XCTAssertEqual(spanAttributes[longKey] as? String, longValue)
        XCTAssertEqual(eventAttributes[longKey] as? String, longValue)
        XCTAssertEqual(linkAttributes[longKey] as? String, longValue)
        XCTAssertEqual(logAttributes[longKey] as? String, longValue)

        // and the same attribute is truncated for users
        let userAttributes = sanitizer.sanitizeLogAttributes([longKey: longValue], source: .user)
        XCTAssertEqual(userAttributes.count, 1)
        XCTAssertEqual(userAttributes.keys.first?.count, 128)
        XCTAssertEqual((userAttributes.values.first as? String)?.count, 1024)
    }

    func test_captureService_attributeCountLimitsApply() throws {
        // given a sanitizer with a limit of 2 attributes for capture services
        let limits = SessionLimits(
            captureService: SignalLimits(
                customSpans: SignalLimits.SpanLimits(attributeCount: 2),
                events: SignalLimits.SpanEventLimits(attributeCount: 2),
                links: SignalLimits.SpanLinkLimits(attributeCount: 2),
                logs: SignalLimits.LogLimits(attributeCount: 2)
            )
        )
        let sanitizer = DefaultOtelSignalsSanitizer(sessionLimits: limits)

        // when sanitizing attributes for capture services
        // then the count limits are applied, without truncating
        let span = sanitizer.sanitizeSpanAttributes(testAttributes, source: .captureService)
        XCTAssertEqual(span.count, 2)
        XCTAssertEqual(span["123456789"] as? String, "123456789")
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributes(testAttributes, source: .captureService).count, 2)
        XCTAssertEqual(sanitizer.sanitizeSpanLinkAttributes(testAttributes, source: .captureService).count, 2)
        XCTAssertEqual(sanitizer.sanitizeLogAttributes(testAttributes, source: .captureService).count, 2)
    }

    func test_sdk_isNotSanitized() throws {
        // given a sanitizer with very small limits for every source
        let tiny = SignalLimits(
            customSpans: SignalLimits.SpanLimits(nameLength: 1, attributeCount: 1),
            events: SignalLimits.SpanEventLimits(nameLength: 1, attributeCount: 1),
            links: SignalLimits.SpanLinkLimits(attributeCount: 1),
            logs: SignalLimits.LogLimits(attributeCount: 1)
        )
        let tinyAttributes = AttributeLengthLimits(keyLength: 1, valueLength: 1)
        let sanitizer = DefaultOtelSignalsSanitizer(
            sessionLimits: SessionLimits(user: tiny, captureService: tiny),
            attributeLimits: AttributeLimits(user: tinyAttributes, captureService: tinyAttributes)
        )

        // when sanitizing SDK signals
        // then nothing changes
        XCTAssertEqual(sanitizer.sanitizeSpanName(" name ", source: .sdk), " name ")
        XCTAssertEqual(sanitizer.sanitizeSpanEventName(" name ", source: .sdk), " name ")
        XCTAssertEqual(sanitizer.sanitizeAttributeKey("key", source: .sdk), "key")
        XCTAssertEqual(sanitizer.sanitizeAttributeValue("value", source: .sdk) as? String, "value")
        XCTAssertEqual(sanitizer.sanitizeSpanAttributes(testAttributes, source: .sdk).count, 3)
        XCTAssertEqual(sanitizer.sanitizeSpanEventAttributes(testAttributes, source: .sdk).count, 3)
        XCTAssertEqual(sanitizer.sanitizeSpanLinkAttributes(testAttributes, source: .sdk).count, 3)
        XCTAssertEqual(sanitizer.sanitizeLogAttributes(testAttributes, source: .sdk).count, 3)
        XCTAssertEqual(sanitizer.sanitizeLogAttributes(testAttributes, protecting: [], source: .sdk).count, 3)
    }
}
