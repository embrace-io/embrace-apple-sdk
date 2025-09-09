//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

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
        XCTAssertEqual(attributeValue, "12345")
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
        XCTAssertEqual(attributes["123"], "123")
        XCTAssertEqual(attributes["12345"], "12345")
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
        XCTAssertEqual(attributes["123"], "123")
        XCTAssertEqual(attributes["12345"], "12345")
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
        XCTAssertEqual(attributes["123"], "123")
        XCTAssertEqual(attributes["12345"], "12345")
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
        XCTAssertEqual(attributes["123"], "123")
        XCTAssertEqual(attributes["12345"], "12345")
    }
}
